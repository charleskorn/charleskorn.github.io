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

# Work around issues with rate limiting on some external sites (eg. YouTube) when checking links from Travis
if [ "$TRAVIS" = "true" ]; then
  HTMLPROOF_EXTRA_ARGS="--disable-external"
else
  HTMLPROOF_EXTRA_ARGS=""
fi

bundle exec htmlproofer ./_site --only-4xx --check-favicon --check-html --url-ignore '#' $HTMLPROOF_EXTRA_ARGS

bundle exec github-pages health-check
