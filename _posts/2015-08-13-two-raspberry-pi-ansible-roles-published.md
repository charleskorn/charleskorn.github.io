---
layout: post
title:  Two Raspberry Pi Ansible roles published
date:   2015-08-13 19:30:00 +10:00
tags:   ansible raspberry-pi hardware
comments: true
---

Over the weekend I published two [Ansible](http://www.ansible.com/) roles for automating common set up
tasks for a [Raspberry Pi](https://www.raspberrypi.org/):

* [raspi-information-radiator](https://github.com/charleskorn/raspi-information-radiator): configures a
  Raspberry Pi as an information radiator, automatically launching Chromium to display a web page in full
  screen mode on boot. (This is based on the article
  [HOWTO: Boot your Raspberry Pi into a fullscreen browser kiosk](http://blogs.wcode.org/2013/09/howto-boot-your-raspberry-pi-into-a-fullscreen-browser-kiosk/).)

* [raspi-expanded-rootfs](https://github.com/charleskorn/raspi-expanded-rootfs): expands the root
  filesystem of a Raspberry Pi to fill the available space.

They're also available on [Ansible Galaxy](https://galaxy.ansible.com/list#/users/13711).

The readme files for both roles include more information on how they work and an example of how to use them.

Both of them have some opportunities for improvement, and pull requests and issue reports are most welcome.

