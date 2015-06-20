#!/usr/bin/env bash

set -e

echo --------------------------------------
echo Building...
echo --------------------------------------
echo
JEKYLL_ENV=production bundle exec jekyll build

echo
echo --------------------------------------
echo Checking...
echo --------------------------------------
echo
bundle exec htmlproof ./_site --only-4xx --check-favicon --check-html --href-ignore '#'
