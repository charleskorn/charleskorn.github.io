---
layout: post
title:  An Ansible role for running ACIs with systemd
tags:   containers deployment devops rkt ansible aci systemd
date:   2015-06-20 15:50:00 +10:00
---

Following on from [my previous blog post about rkt]({% post_url 2015-06-20-my-experiences-with-rkt-an-alternative-to-docker %}), 
I've published an Ansible role I use to deploy a simple systemd service unit that runs an ACI (the image format used by rkt).

You can find it on Ansible Galaxy at [https://galaxy.ansible.com/list#/roles/3736](https://galaxy.ansible.com/list#/roles/3736), 
and on GitHub at [https://github.com/charleskorn/rkt-runner](https://github.com/charleskorn/rkt-runner).

_Like the previous post, this written for the v0.5.5 release of rkt, so some things may be slightly outdated._
