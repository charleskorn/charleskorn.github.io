---
layout: post
title: Docker-based development environment IDE support
tags: docker containers development-environment
date: 2017-05-25 09:54:00 +02:00
comments: true
---

I've been talking quite a bit lately about Docker-based build environments 
([in Hamburg](http://charleskorn.com/2017/01/17/dockers-not-just-for-production-using-containers-for-your-development-environment/), 
[in Munich](/2017/03/30/dockers-not-just-for-production-using-containers-for-your-development-environment/), and at many of our clients).

One of the biggest drawbacks of the technique is the poor integration story for IDEs. Many IDEs require that your build environment 
(eg. target JVM and associated build tools) is installed locally to enable all of their useful features like code completion and test runner 
integration. But if this is isolated away in a container, the IDE can’t access it, so all these handy productivity features won't work.

However, it looks like JetBrains in particular is starting to integrate these ideas into their products more:

* WebStorm will now allow you to configure a 'remote' Node.js interpreter in a local Docker image ([details here](https://blog.jetbrains.com/webstorm/2017/04/quick-tour-of-webstorm-and-docker/))
* RubyMine takes this one step further: you can configure a Ruby interpreter based on a service definition in a Docker Compose 
  file ([details here](https://blog.jetbrains.com/ruby/2017/05/rubymine-2017-2-eap-1-docker-compose/)). A similar feature is available
  for Python in PyCharm.
  
Both of these are great steps forward, and if you're using Docker-based build environments, I'd encourage you to take a look at this.

Now, if only they'd do this for JVMs in IntelliJ... 
