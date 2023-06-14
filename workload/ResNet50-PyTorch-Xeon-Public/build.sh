#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="ai_common" "$DIR"/../../stack/ai_common/build.sh $@
STACK="pytorch_xeon_public" "$DIR"/../../stack/PyTorch-Xeon/build.sh $@

WORKLOAD=${WORKLOAD:-resnet50_pytorch_xeon_public}

. "$DIR"/../../script/build.sh
