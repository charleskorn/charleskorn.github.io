---
layout: post
title: "How I collect telemetry from Batect users"
tags: open-source telemetry google-cloud bigquery golang batect
comments: true
---

I'm constantly asking myself a bunch of questions to help improve Batect: are Batect's users having a good experience? What's not working well? How are they using Batect?
What could Batect do to make their lives easier?

I first released [Batect](https://batect.dev) back in 2017. Since then, the userbase has grown from a handful of people that could fit around a single
desk to hundreds of people all over the globe.

Back when everyone could fit around a desk, answering these questions was easy: I could stand up, walk over to someone, and ask them. (Or, if I was feeling particularly
lazy, I could just stay seated and ask over the top of my screen.) 

But with this growth in use, now I have another question: how do I break out of my bubble and feedback and ideas from those I don't know?

This is where telemetry data comes into the picture. In addition to feedback signals like GitHub issues, discussions, suggestions and the surveys I occasionally run,
telemetry data has been invaluable to help me get a broader understanding of how users use Batect, the problems they run into and the environments they use Batect in.
This in turn has helped me prioritise the features and improvements that will have the greatest impact and design them in a way that will be the most useful for Batect's users.

In this post, I'm going to talk through what I mean by telemetry data, how I went about designing the telemetry collection system and finish off with two stories of how I've used
this data.

**_TABLE OF CONTENTS HERE?_**

## Telemetry?

* What is telemetry?

Similar to Honeycomb's definition of observability for production systems, I wanted to be able to answer questions about Batect and it's users I haven't even thought of yet.

**_add link to definition of observability above_**

## Key design considerations

* Low impact on app performance
* Cost
* Privacy
* Security
* Availability
* Ease of maintenance
* Flexibility - ability to add other data / attributes in the future, ability to answer questions I don't yet know I want to ask

Things to emphasise:
* Opt-in telemetry


## The design

* Walk through flow of events through system
  * Introduce concept of session


[![Diagram showing main components in the system and the steps in data flow](/images/2022/abacus-overview.svg)](/images/2022/abacus-overview.svg)

* Show examples of client code that captures spans / events / attributes?


## Examples of where I've used this data

Some of my favourite stories of how I've used this data are for prioritising Batect's shell tab completion functionality and validating that it had the
intended impact, and for prioritising contributing support for Batect to [Renovate](https://github.com/renovatebot/renovate).

### Shell tab completion

Batect's main user interface is the command line: to run a task, you execute a command like `./batect build` or `./batect test` from your shell.
One of the most frequently-requested features was support for shell tab completion, so that instead of typing out `build` or `test`, you could type
just the first letter or two, press <kbd>Tab</kbd>, and the rest of the task name would be completed for you.

While I could definitely see the value in this, I was worried I was over-emphasising features I'd like to see based on how I usually work and interact
with applications, and wanted to confirm that this would actually be valuable for a large portion of Batect's userbase. I formed a hypothesis that shell 
tab completion would help reduce the number of sessions that fail because the task name cannot be found, likely because of a typo. 

So, I turned to the data I had and found that roughly 2.6% of sessions fail because the task cannot be found. This seemed very high and was enough for me to
feel confident investing some time and effort implementing [shell tab completion](https://batect.dev/docs/getting-started/shell-tab-completion).

Of course, the next question was which shell to focus on first: Bash? Zsh? My personal favourite, Fish? My gut told me most people would likely be using 
Zsh or Bash as their default shell, but here the data told a different story: the shells used most commonly by Batect's users are actually Fish and Zsh.
So that's where I started - I added tab completion functionality for both Fish and Zsh - and, thanks to the data I had, I was able to prioritise my limited
time to focus on the shells that would help the largest number of users.

And, thanks once again to telemetry data, once I'd released this feature, I was also able to quickly validate my hypothesis: users that use shell tab completion experience
"task not found" errors over 30% less than those that don't use it.

### Renovate

Before: X% of sessions were using the latest available version
After: X% of sessions were using the latest available version

## In closing



* Link to GitHub repos




* Things that work well
* Things that don't work well
* Go through remaining TODOs
* Table of contents?
