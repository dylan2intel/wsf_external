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
source "$DIR"/ai_common/libs/run_cmd.sh

# Precheck
show_info "WORKLOAD PLATFORM MODE TOPOLOGY FUNCTION PRECISION BATCH_SIZE STEPS DATA_TYPE CORES_PER_INSTANCE WEIGHT_SHARING CASE_TYPE ONEDNN_VERBOSE MPI NUM_MPI CUSTOMER_ENV VERBOSE"
precondition_check $BATCH_SIZE $INSTANCE_NUMA

# Set env variable
set_tf_env
set_tf_case_env
set_tf_verbose_env

# Set resnet50v1_5 tf args
ARGS=$(resnet50v1_5_tf_args)

if [ "$VERBOSE" == "True" ]; then
    ARGS+=" --verbose"
fi

echo "Running..."

# Run benchmark
if [ "$MODE" == "accuracy" ]; then
    python benchmarks/launch_benchmark.py ${ARGS}
else
    run_cmd "python benchmarks/launch_benchmark.py ${ARGS}"
fi

echo "Summary..."
