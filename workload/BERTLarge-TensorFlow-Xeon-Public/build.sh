#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

# if [ $PLATFORM == "MILAN" ] || [ $PLATFORM == "ROME" ]; then
#     FIND_OPTIONS="( -name Dockerfile.2.dataset -o -name Dockerfile.1.AMD-real  $FIND_OPTIONS )"
# else
#     FIND_OPTIONS="( -name Dockerfile.2.dataset -o -name Dockerfile.1.intel-real $FIND_OPTIONS )"
# fi

STACK=ai_common "$DIR"/../../stack/ai_common/build.sh $@
STACK="tensorflow_xeon" "$DIR"/../../stack/TensorFlow-Xeon/build.sh public $@

WORKLOAD=${WORKLOAD:-bertlarge-tensorflow-xeon-public}

. "$DIR"/../../script/build.sh
