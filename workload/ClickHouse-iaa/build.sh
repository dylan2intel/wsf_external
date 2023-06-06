#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
STACK="ClickHouse-iaa" "$DIR"/../../stack/ClickHouse-iaa/build.sh $@
. "$DIR"/../../script/build.sh

