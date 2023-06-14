#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
STACK="rocksdb" "$DIR/../../stack/RocksDB/build.sh" $@

. "$DIR/../../script/build.sh"