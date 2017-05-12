#!/bin/sh

source `dirname $0`/../common.sh
source `dirname $0`/common.sh

docker run -v $OUTPUT_DIR:/tmp/output -v $CACHE_DIR:/tmp/cache -e VERSION=1.7.27 -e RUBY_VERSION=1.9.3 -t hone/jruby-builder:$STACK
