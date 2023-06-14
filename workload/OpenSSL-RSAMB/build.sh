#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

# build dependencies
if [[ "$WORKLOAD" = *_qathw ]]; then
    STACK="qat_setup" "$DIR/../../stack/QAT-Setup/build.sh" $@
fi

# build workload images
FIND_OPTIONS="-name *.${WORKLOAD/*_/}"
. "$DIR"/../../script/build.sh
