#!/bin/bash -e

OPTION=${1:-inference_throughput_avx_fp32_gated}
PLATFORM=${PLATFORM:-SPR}
WORKLOAD=${WORKLOAD:-resnet50v1_5}

TOPOLOGY="resnet50v1_5"
FUNCTION=$(echo ${OPTION}|cut -d_ -f1)
MODE=$(echo ${OPTION}|cut -d_ -f2)
CASE_TYPE=$(echo ${OPTION}|cut -d_ -f5)

PRECISION=$(echo ${OPTION}|cut -d_ -f3-4)
DATA_TYPE=${DATA_TYPE:-dummy}
STEPS=${STEPS:-10}

if [ "$MODE" == "accuracy" ]; then
    BATCH_SIZE=${BATCH_SIZE:-100}
    DATA_TYPE=real
else
    BATCH_SIZE=${BATCH_SIZE:-1}
fi

CORES_PER_INSTANCE=${CORES_PER_INSTANCE:-4}

if [ "$MODE" == "latency" ] && [ "$PRECISION" != "avx_fp32" ] && [ "$PRECISION" != "amx_bfloat32" ]; then
    WEIGHT_SHARING=${WEIGHT_SHARING:-True}
else 
    WEIGHT_SHARING=${WEIGHT_SHARING:-False}
fi

TRAIN_EPOCH=${TRAIN_EPOCH:-10}
VERBOSE=${VERBOSE:-False}
ONEDNN_VERBOSE=${ONEDNN_VERBOSE:-False}
MPI=${MPI:-1}
NUM_MPI=${NUM_MPI:-0}
CUSTOMER_ENV=${CUSTOMER_ENV:-"ONEDNN_VERBOSE=0"}

if [ "$CASE_TYPE" == "pkm" ]; then
    EVENT_TRACE_PARAMS="roi,Running...,Summary..."
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

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Docker Setting
if [[ "$WORKLOAD" = *sgx ]]; then
    DOCKER_IMAGE="$DIR/sgx/Dockerfile.1.intel-public-inference";
else
    DOCKER_IMAGE="$DIR/Dockerfile.1.intel-public-inference";
fi

ALL_KEYS="WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE STEPS DATA_TYPE CORES_PER_INSTANCE WEIGHT_SHARING TRAIN_EPOCH CASE_TYPE ONEDNN_VERBOSE MPI NUM_MPI CUSTOMER_ENV VERBOSE"

# Workload Setting
WORKLOAD_PARAMS=($ALL_KEYS)
DOCKER_ARGS=$(eval echo \"$(docker_settings $ALL_KEYS)\")
DOCKER_OPTIONS="--privileged $DOCKER_ARGS"

# Kubernetes Setting
K8S_PARAMS=$(eval echo \"$(k8s_settings $ALL_KEYS)\")
RECONFIG_OPTIONS="${K8S_PARAMS} -DDOCKER_IMAGE=${DOCKER_IMAGE}"

JOB_FILTER="job-name=resnet50v15-tensorflow-xeon-public-benchmark"

. "$DIR/../../script/validate.sh"
