#!/bin/sh

docker run -v `pwd`/builds:/tmp/output -v `pwd`/../cache:/tmp/cache -e VERSION=9.0.0.0.pre1 -e RUBY_VERSION=2.2.0 -t hone/jruby-builder:cedar-14
