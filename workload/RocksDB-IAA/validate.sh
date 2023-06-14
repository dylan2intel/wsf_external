#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
TYPE=${1:-readrandom}
KEY_SIZE=${KEY_SIZE:-16}
VALUE_SIZE=${VALUE_SIZE:-32}
BLOCK_SIZE=${BLOCK_SIZE:-16384} # 16k
THREADS_NUM=${THREADS_NUM:-8}
NUMA_OPTIONS=${NUMA_OPTIONS:-"numactl%20--cpubind=0%20--membind=0"}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

WORKLOAD_PARAMS=(TYPE KEY_SIZE VALUE_SIZE BLOCK_SIZE THREADS_NUM)

# Docker Setting
DOCKER_IMAGE="$(ls -1 "$DIR"/Dockerfile)"
DOCKER_OPTIONS="--privileged -e TYPE=${TYPE} -e KEY_SIZE=${KEY_SIZE} -e VALUE_SIZE=${VALUE_SIZE} -e BLOCK_SIZE=${BLOCK_SIZE} -e THREADS_NUM=${THREADS_NUM} -e NUMA_OPTIONS=${NUMA_OPTIONS}"
# Kubernetes Setting
RECONFIG_OPTIONS="-DTYPE=$TYPE -DKEY_SIZE=$KEY_SIZE -DVALUE_SIZE=$VALUE_SIZE -DBLOCK_SIZE=$BLOCK_SIZE -DTHREADS_NUM=$THREADS_NUM -DNUMA_OPTIONS=$NUMA_OPTIONS"
JOB_FILTER="job-name=rocksdb-iaa"

# kpi args
SCRIPT_ARGS=$(echo ${TYPE} | cut -d"_" -f2)

. "$DIR/../../script/validate.sh"