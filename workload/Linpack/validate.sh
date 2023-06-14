#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-linpack}
ASM=${1:-default_instruction}
ARCH=${2:-intel}
N_SIZE=${N_SIZE:-auto}
SHMSIZE=${SHM_SIZE:-16}

function k8s_settings() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="-DK_$i=\$$i"
        else
            RET="${RET} -DK_$i=\$$i"
        fi
    done
    echo "$RET"
}

function docker_settings() {
    RET=""
    for i in "$@"; do
        if [[ "$RET" == "" ]]; then
            RET="-e $i=\$$i"
        else
            RET="${RET} -e $i=\$$i"
        fi
    done
    echo "$RET"
}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Docker Setting
if [ ! "$BACKEND" == "nova" ]; then
    DOCKER_IMAGE="$DIR/Dockerfile.1.${ARCH}"
else
    DOCKER_IMAGE="$DIR/nova-config/Dockerfile"
fi

ALL_KEYS="WORKLOAD PLATFORM N_SIZE ASM SHM_SIZE"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged --shm-size=${SHMSIZE}gb $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"