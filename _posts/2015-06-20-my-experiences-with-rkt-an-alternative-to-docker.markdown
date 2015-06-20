---
layout: post
title:  "My experiences with rkt, an alternative to Docker"
date:   2015-06-20 14:25:00 +10:00
tags:   containers coreos deployment devops docker rkt
---

_This post was written for the v0.5.5 release of rkt, so some things may be slightly outdated._

I've recently been experimenting with [rkt](https://github.com/coreos/rkt) (pronounced 'rock-it'), 
a tool for running app containers. rkt comes from the team at [CoreOS](https://coreos.com/), who you 
might know from other projects such as [etcd](https://coreos.com/etcd/) and 
[fleet](https://github.com/coreos/fleet). rkt is conceptually similar to Docker, but was developed by 
CoreOS to address some of the shortcomings they perceive in Docker, particularly around security and modularity. 
They wrote up a great general overview of their approach in [the rkt announcement blog post](https://coreos.com/blog/rocket/).

I was initially drawn to rkt because of the difficulty running Docker on a Raspberry Pi without recompiling the kernel. (Although, as of now, I still haven't got rkt running on it either - that should change soon though, see below.)

My goal with this blog post is to discuss some of the things I've liked about rkt, and some of the frustrations.

# Image build process
The first thing that struck me about rkt was the simplicity and speed of the image build process. 
[A simple image for a personal project](https://github.com/charleskorn/weather-thingy-data-service/blob/master/rkt/manifest.json)
takes four seconds to build, and most of that is spent compiling the Golang project that makes up the image. 
([This](https://github.com/charleskorn/weather-thingy-data-service/blob/master/build.sh) is the shell 
script that I use to compile that image if you're interested.) This simplicity and speed stems from the fact that 
neither the image nor its base image (if there is one) are actually started during the build process when using the 
standard build tool (`actool`). Instead, each image is created from the files it requires and a list of 
images it depends on to run. Not booting the container also eliminates the need to download the base images to the 
build machine, saving further time. Moreover, the runtime provides a standard base image upon which all other images 
are run (called the stage 1 image), eliminating the need for a base image in many simple cases. (Similar to Docker, 
the "merging" of the top-level image with its dependencies happens at runtime, using 
[overlayfs](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt) if available on the host.)

Removing the need to boot up an image during the build process also has some other advantages. It makes it far 
easier to run on different architectures or operating systems to those on the target machine. For example, it's 
quite easy to build an image targeting Linux from OS X, and no tools like [boot2docker](http://boot2docker.io/) 
are required. Furthermore, the build process can be run as an unprivileged (non-root) user, which can make life easier in 
restricted hosted build environments.

However, this approach does have one major drawback that can make life very painful. As the container is not booted, 
tools such as `apt-get` can't be used to easily install dependencies - you're responsible for ensuring that 
all dependencies find their way onto the image yourself. With a simple Golang server, for example, this isn't a big issue, 
as it's quite straightforward to produce a statically-linked binary, but for many other languages this can be problematic as 
the entire runtime and their dependencies are required (eg. a JVM, Ruby runtime etc.).

# Separation of build tools and runtime
As I mentioned earlier, one of the major focus areas has been on modularity and enabling developers to use the most 
appropriate tool for the job, rather than the more one-size-fits-all approach of Docker. As such, the runtime 
(`rkt`) is completely separate from the build tool (`actool`), and either could be completely replaced 
by another tool - the specification they conform to is 
[available on GitHub](https://github.com/appc/spec/blob/master/SPEC.md). There are already 
[some alternative runtime implementations](https://github.com/appc/spec#what-are-some-implementations-of-the-spec) 
and [a variety of different tools](https://github.com/appc/spec#what-is-the-promise-of-the-app-container-spec) springing up.

# Security / image verification model
One of the most interesting aspects of rkt is its security model. rkt comes with cryptographic verification of images enabled 
by default (and defaults to trusting no signing keys). This enables you to ensure that not only are public images are from 
those you trust, but also that any private images you upload to services outside your control are unmodified when you pull 
them back down again. It's also pretty straightforward to set up and running, with 
[a good guide available on GitHub](https://github.com/coreos/rkt/blob/master/Documentation/signing-and-verification-guide.md).

# Compatibility with Docker
Although I haven't tried this myself, it's possible to run Docker images with the rkt runtime, if you need to run both Docker and 
rkt images side-by-side. ([source](https://github.com/coreos/rkt/blob/master/Documentation/running-docker-images.md))

# Documentation 
rkt is still very much under active development - there have been 14 releases since the first at the end of November last year - 
which means what little documentation and online resources are out there are generally made obsolete very quickly, which can be a 
bit of a pain at times. There is a focus on stabilising things with the upcoming 0.6 release, but until that materialises, keep in 
mind that anything you're reading now could be very out of date.

Furthermore, the official documentation is patchy - some places (such as the 
[app container specification](https://github.com/appc/spec)) are thorough, whilst 
[other places are full of placeholders](https://github.com/coreos/rkt/blob/master/Documentation/commands.md).

# Multiple architectures
Because the stage 1 image is provided by the host environment, building images for different architectures is (theoretically) easier - 
if your image does not require a specific base image, all you need to do is recompile your binaries for the other architecture. 
(I say theoretically because I haven't yet tried it myself - I'm still waiting for 
[support for running containers on ARM processors](https://github.com/coreos/rkt/issues/730), which is expected in the 0.6 
release.)

# Conclusion
I've really liked working with rkt so far - it's been very quick to get up and running and there wasn't a lot of fussing around to get 
something simple working, even in its current form. There are still some rough edges, particularly around documentation, and some things 
that can make life frustrating, like dealing with dependencies, but there is definitely a lot of potential. It's going to be very 
interesting to watch rkt evolve.
