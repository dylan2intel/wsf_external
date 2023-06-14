#! /bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/set_env_tf.sh
source "$DIR"/ai_common/libs/precheck.sh
source "$DIR"/ai_common/libs/tf_args.sh

# Precheck
show_info "WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE STEPS DATA_TYPE CORES_PER_INSTANCE MAX_SEQ_LENGTH WEIGHT_SHARING CASE_TYPE TOTAL_SAMPLES DATASET ONEDNN_VERBOSE ENABLE_PROFILING CUSTOMER_ENV CLOUD_CORES_BIND"
precondition_check $BATCH_SIZE $INSTANCE_NUMA

# Set env variable
set_tf_env
set_tf_case_env
set_tf_verbose_env

# Set bertlarge tf args
ARGS=$(bertlarge_tf_args)

INSTANCE_NUMBER=$(expr ${TOTAL_CORES} \/ ${CORES_PER_INSTANCE})

if [ "$VERBOSE" == "True" ]; then
    ARGS+=" --verbose"
fi

if [[ "$PRECISION" =~ "int8" ]]; then
    echo "$PRECISION precision are not supported"
    exit 1
fi

# Set launch args
if [ "$FUNCTION" == "inference" ] ; then
    if [ "$MODE" == "latency" ]; then
        if [[ "$WEIGHT_SHARING" == "True" ]]; then
            LAUNCH_ARGS+=" --ninstances ${NUMA_NODES}"
        elif [ "$CORES_PER_INSTANCE" != "-1" ]; then
            LAUNCH_ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE}"
        else
            LAUNCH_ARGS+=" --latency_mode"
        fi
    elif [ "$MODE" == "throughput" ]; then
        if [ "$CORES_PER_INSTANCE" != "-1" ]; then
            LAUNCH_ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE} \
                           --ninstances ${INSTANCE_NUMBER}"
        else
            LAUNCH_ARGS+=" --throughput_mode"
        fi
    elif [ "$MODE" == "accuracy" ]; then
        if [ "$CORES_PER_INSTANCE" != "-1" ]; then
            LAUNCH_ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE} \
                           --ninstances 1"
        else
            LAUNCH_ARGS+=" --node_id 0"
        fi
    fi
elif [ "$FUNCTION" == "training" ]; then
    LAUNCH_ARGS+=" --node_id 0"
    if [ "$CORES_PER_INSTANCE" != "-1" ]; then
        LAUNCH_ARGS+=" --ncore_per_instance ${CORES_PER_INSTANCE} \
                       --ninstances 1"
    fi
else
    echo "Error, not support function ${FUNCTION}"
    exit 1
fi

if [[ "$CLOUD_CORES_BIND" == "True" ]];then
    TOTAL_CORES=$(expr ${TOTAL_CORES} \* ${THREADS_PER_CORE})
    CORES_PER_INSTANCE=${TOTAL_CORES}
    LAUNCH_ARGS="--ncore_per_instance ${CORES_PER_INSTANCE} --ninstances 1 --use_logical_core"
fi

echo "Running..."

# Run benchmark
if [ "$FUNCTION" == "training" ] || [ "$MODE" == "accuracy" ]; then
    python benchmarks/launch_benchmark.py ${ARGS}
else
    python "$DIR"/ai_common/libs/launch.py ${LAUNCH_ARGS} benchmarks/launch_benchmark.py ${ARGS}
fi

echo "Summary..."
