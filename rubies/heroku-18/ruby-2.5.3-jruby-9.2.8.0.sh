#!/bin/sh

source `dirname $0`/../common.sh
source `dirname $0`/common.sh

docker run -v $OUTPUT_DIR:/tmp/output -v $CACHE_DIR:/tmp/cache -e VERSION=9.2.8.0 -e RUBY_VERSION=2.5.3 -t hone/jruby-builder:$STACK
