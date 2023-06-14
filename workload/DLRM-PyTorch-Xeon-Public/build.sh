#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="pytorch_xeon_public" "$DIR"/../../stack/PyTorch-Xeon/build.sh $@

WORKLOAD=${WORKLOAD:-dlrm_pytorch_xeon_public}

case ${WORKLOAD} in
    *inference_accuracy* )
        FIND_OPTIONS="( -name Dockerfile.?.dataset -o -name Dockerfile.?.model -o -name Dockerfile.?.benchmark -o -name Dockerfile.?.inference.accuracy $FIND_OPTIONS )"
        ;;
    *inference_throughput* )
        FIND_OPTIONS="( -name Dockerfile.?.dataset -o -name Dockerfile.?.benchmark -o -name Dockerfile.?.inference $FIND_OPTIONS )"
        ;;
    *training* )
        FIND_OPTIONS="( -name Dockerfile.?.dataset -o -name Dockerfile.?.benchmark -o -name Dockerfile.?.training $FIND_OPTIONS )"
        ;;
    * )
        FIND_OPTIONS=$FIND_OPTIONS
        ;;
esac

. "$DIR"/../../script/build.sh
