---
layout: post
tags: testing databases integration-testing sql-server performance
date:   2016-03-30 9:30:00 +11:00
title: Fast(er) database integration testing with snapshots
comments: true
---

On a recent project, we were struggling with our integration test suite. A full run on a developer PC could take up to 15 minutes. As you'd expect, that was having a significant impact on our productivity.

So we decided to investigate the issue and quickly discovered that the vast majority of that 15 minutes was spent spinning up and then destroying test databases for each test, rather than executing the tests themselves. (In the interests of test isolation, each individual test was given its own fresh database.) We didn't want to stop giving each test a clean database, because we liked the independence guarantee that gave us, but at the same time, a 15 minute test run was well past the point of being bearable. There had to be a better way... 

## Some context

We were using SQL Server and the database schema we were testing against was a behemoth that had grown over many years to contain somewhere around 50 to 100 tables, plus dozens of stored procedures, views and indices. Creating a new database from scratch with this schema took 15-30 seconds.

Our production environment had nearly 1 TB of data, with most of that concentrated in two key tables that we frequently queried in different ways. As you can imagine, achieving an acceptable level of performance with this volume of data was challenging at times. (Thankfully we didn't need that much data for each test.)

Because of this, we had a large amount of hand-crafted, artisanal SQL and were using [Dapper](https://github.com/StackExchange/dapper-dot-net). We had previously been using [Fluent NHibernate](http://www.fluentnhibernate.org/) to construct our queries, but found that NHibernate introduced a significant performance penalty which was not acceptable in our case. Furthermore, many queries involved a large number of joins and conditions that were awkward to express using the fluent interface and often resulted in inefficient generated SQL. They were much more expressive, concise and efficient in hand-written SQL. 

Furthermore, some parts of the application wrote to the database, and different tests required different sets of data, so we couldn't have one read-only database shared by all tests. Due to the number of database interactions under test and the number of tests, we wanted something that would have a minimal impact on the existing code. 

## The existing solution

The existing test setup looked like this:

1. Restore database backup with schema and base data
2. Insert test-specific data from CSV files
3. Run test
4. Destroy test database
5. Repeat steps 1 to 4 for each test

Apart from the performance issue I've already talked about, we also wanted to try to address some of these issues:

* The database was created from a backup stored on a shared network folder, meaning anyone could break the tests for everyone at any time. Moreover, it wasn't under source control, so we couldn't easily revert back to an old version if need be.

* The database was a binary file that was not easy to diff, which made it difficult to work out what had changed when tests suddenly started breaking.

* Any schema changes that were made needed to be manually applied to the database backup file (applying any new database migrations was not included in the test set up process). This meant tests weren't always running against the most recent version of the schema.

## What are snapshots?

Before we jump into talking about how we improved the performance of our tests, it's important to understand [SQL Server's snapshot feature](https://msdn.microsoft.com/en-us/library/ms175158.aspx). Other database engines have similar mechanisms available, some built-in, some relying on file system support, but we were using SQL Server so that's what I'll talk about here. (Snapshots are unrelated to other things with the word 'snapshot' in them, such as snapshot isolation.)

Snapshots are just a read-only copy of an existing database, but the way in which they are implemented is critical to the performance gains we saw. Creating a snapshot is a low-cost operation as there is no need to create a full copy of the original database on disk. Instead, when changes are made to the original database, the affected database pages are duplicated on disk before those changes are applied to the original pages. 

Then, when the time comes to restore the snapshot, it is just a matter of deleting the modified pages and replacing them with the untouched copies made earlier. And the fewer changes you make after the snapshot, the faster it is, as fewer pages need to be restored. This means that the act of restoring the database from a snapshot is very, very fast, and certainly much faster than recreating the database from scratch. This makes them well suited to our needs -- we were recreating the database to get to a known clean state before the start of each test, but this achieves the same effect in much less time.

(If you're interested in learning more, there are more details about how snapshots work and how to use them on [MSDN](https://msdn.microsoft.com/en-us/library/ms175158.aspx).)

## Introducing snapshots into our test process

After a few iterations, we arrived at this point:

1. Create empty test database
2. Run initial schema and base data creation script
3. Apply any migrations created since the initial schema and data script had been created
4. Take a snapshot of the database
5. Restore database from snapshot
6. Insert test-specific data from CSV files
7. Run test
8. Repeat steps 5 to 7 for each subsequent test
9. Destroy snapshot and test database

While this approach might be slightly more complicated, it gave us a huge performance boost (down to around 8 minutes). We were no longer spending a significant amount of time creating and destroying databases for each test.

There are a few other things of note:

* Step 5 (restoring the database from the snapshot) isn't strictly necessary for the first test. We left it there anyway, instead of moving it to after running the test, just to make it clear that each test started with a clean slate. Also, as I mentioned earlier, the cost of restoring from a snapshot is negligible, especially when there are no changes, so this does not significantly increase the run time of the test.

* We addressed our first two 'nice to haves' by turning the binary database backup into an equivalent SQL script that recreated the schema and base data (used in step 2), and put this file under source control. Running the script rather than restoring the backup was marginally slower, but we were happy to trade speed for maintainability in this case, especially given that we'd only have to run the script once per test run.

* Step 3 (running any outstanding migrations) addressed the final 'nice to have'. We couldn't just build up the database from scratch with migrations because for some of the earliest parts of the schema, there weren't any migration scripts. Also, we found that building a minimal schema script (and leaving the rest of the work to the migrations we did have) was a time-consuming, error-prone manual process. 

## Adding a dash of parallelism

Despite our performance gains, we still weren't satisfied -- we knew we could do even better. The final piece of the puzzle was to take advantage of [NUnit 3's parallel test run support](https://github.com/nunit/docs/wiki/Framework-Parallel-Test-Execution) to run our integration tests in parallel. 

However, we couldn't just sprinkle `[Parallelizable]` throughout the code base and head home for the day. If we did that without making any further changes, each test running at the same time would be using the same test database and would step on each other's toes. We didn't want to go back to having each test create its own database from scratch either though, because then we'd lose the performance gains we'd achieved. 

Instead, we introduced the concept of a test database pool shared amongst all testing threads. The idea was that as each test started, it would request a database from the pool. If one was available, it was returned to the test and it could go ahead and run with that database. If there weren't any databases available in the pool, we'd create one using the same process as before (steps 1 to 4 above) and then return that database. At the end of the test, it would then return the database to the pool for other tests to use. 

This meant we created the minimum number of test databases (remember that creating the test database was one of the most expensive operations for us), while still realising another significant performance improvement -- our test run was now down to around 5 minutes. While this still wasn't as fast as we'd like (let's be honest, we're impatient creatures, tests can never be fast enough), we were pretty happy with the progress we'd made and needed to start looking at the details of individual tests to improve performance further.

## Other approaches that we tried and discarded
We experimented with a number of other approaches that we chose not to use, but might work in other situations:

* **Using a lightweight in-process database engine (eg. [SQL Server Compact](https://msdn.microsoft.com/en-au/data/ff687142.aspx) or [SQLite](https://www.sqlite.org/)), or something very quick to spin up (eg. [Postgres](http://www.postgresql.org/) in a Docker container)**: while this option looked promising early on, we needed to use something from the SQL Server family so that we were testing against something representative of the production environment, which left SQL Server Compact as the only option. Sadly, SQL Server Compact was missing some key features that we were using, such as views, which instantly ruled it out. (There's a [list of the major differences between Compact and the full version on MSDN](https://technet.microsoft.com/en-us/library/bb896140(v=sql.110).aspx).)

* **Wrapping each test in a transaction, and rolling back the transaction at the end of the test to return the database to a known clean state**: if we were writing our system from scratch, this is the approach I'd take. However, we already had a large amount of code written, and it would have been very time-consuming to rework it all to support being wrapped in a transaction. Most of the database code we had was responsible for creating a database connection, starting a transaction if needed and so on, and so reworking it to support an externally-managed transaction would have required a significant amount of work not only in that code but throughout the rest of the application.

* **Using a read-only test database for code that made no changes to the test database**: at one point in time, a large part of our application only read data from the database, so we considered having two different patterns for database integration testing: one for when we were only reading from the database, and another for when it was modified as part of the test (eg. commands involving `INSERT` statements). We shied away from this approach for the sake of having just one database testing approach.

*Updated April 3: minor edits for clarity, thanks to [Ken McCormack](https://twitter.com/kenmccormack)*

