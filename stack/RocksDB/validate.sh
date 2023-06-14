#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TYPE=${1:-fillseq}
METHOD=${2:-sw}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(TYPE METHOD)

# Docker Setting
DOCKER_IMAGE="$(ls -1 "$DIR"/Dockerfile.1.rocksdb.iaa.unittest)"
DOCKER_OPTIONS="--privileged -v /dev:/dev -v /var/tmp:/var/tmp -v /sys:/sys -v /lib/modules:/lib/modules -e TYPE=${TYPE} -e METHOD=${METHOD}"

# Kubernetes Setting
RECONFIG_OPTIONS="-DTYPE=$TYPE -DMETHOD=$METHOD"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"
