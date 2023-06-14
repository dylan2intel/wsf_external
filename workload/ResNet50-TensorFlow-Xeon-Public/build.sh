#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="tensorflow_xeon" "$DIR"/../../stack/TensorFlow-Xeon/build.sh public $@
STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@

WORKLOAD=${WORKLOAD:-resnet50v1_5_tensorflow_xeon_public}

if [[ "$WORKLOAD" = *sgx ]]; then
    # build sgx gramine base image
    STACK="sgx_gramine" "$DIR/../../stack/SGX-Gramine/build.sh" $@

    DOCKER_CONTEXT=("." "sgx")
fi

. "$DIR"/../../script/build.sh
