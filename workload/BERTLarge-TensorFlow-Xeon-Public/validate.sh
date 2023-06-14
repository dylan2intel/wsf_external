#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OPTION=${1:-inference_throughput_amx_bfloat16}
WORKLOAD=${WORKLOAD:-bertlarge-tensorflow-xeon-public}
PLATFORM=${PLATFORM:-SPR}
TOPOLOGY="bert_large"
FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f5)
PRECISION=$(echo ${OPTION}|cut -d_ -f3-4)
DATA_TYPE=${DATA_TYPE:-real}
BATCH_SIZE=${BATCH_SIZE:-1}
STEPS=${STEPS:-1}
WEIGHT_SHARING=${WEIGHT_SHARING:-False}
CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-}
NUM_SAMPLES=${NUM_SAMPLES:-10833}
TOTAL_SAMPLES="10833"
DATASET="SQuAD"
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-0}
ENABLE_PROFILING=${ENABLE_PROFILING:-0}
CUSTOMER_ENV=${CUSTOMER_ENV}
CLOUD_CORES_BIND=${CLOUD_CORES_BIND:-}

if [[ "${TESTCASE}" =~ "aws" ||
      "${TESTCASE}" =~ "gcp" ||
      "${TESTCASE}" =~ "azure" ||
      "${TESTCASE}" =~ "tencent" ||
      "${TESTCASE}" =~ "alicloud" ]]; then
    CLOUD_CORES_BIND=True
fi

if [ "${FUNCTION}" == "inference" ]; then
    MAX_SEQ_LENGTH="384"
elif [ "${FUNCTION}" == "training" ]; then
    MAX_SEQ_LENGTH="512"
fi

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

if [ -n "$CASE_TYPE" ] && [ "$CASE_TYPE" == "pkm" ]; then
    if [ "$MODE" == "throughput" ]; then
        EVENT_TRACE_PARAMS="roi,Running...,Summary..."
    fi
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.1.intel-public-inference"

ALL_KEYS="WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE STEPS DATA_TYPE CORES_PER_INSTANCE MAX_SEQ_LENGTH WEIGHT_SHARING CASE_TYPE TOTAL_SAMPLES DATASET ONEDNN_VERBOSE ENABLE_PROFILING CUSTOMER_ENV CLOUD_CORES_BIND"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"
