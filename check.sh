#!/usr/bin/env bash

set -e

echo --------------------------------------
echo Building...
echo --------------------------------------
echo
JEKYLL_ENV=production bundle exec jekyll build
