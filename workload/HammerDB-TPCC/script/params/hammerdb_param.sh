#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

### HammerDB settings
export TPCC_NUM_WAREHOUSES=${TPCC_NUM_WAREHOUSES:-50} # default for xlarge case
# export TPCC_THREADS_BUILD_SCHEMA=${TPCC_THREADS_BUILD_SCHEMA:-4} # depends on actual cpu cores, default for xlarge case
export TPCC_HAMMER_NUM_VIRTUAL_USERS=${TPCC_HAMMER_NUM_VIRTUAL_USERS:-"9_9_9"} # default for c6i.xlarge case
export TPCC_MINUTES_OF_RAMPUP=${TPCC_MINUTES_OF_RAMPUP:-2}
export TPCC_RUNTIMER_SECONDS=${TPCC_RUNTIMER_SECONDS:-600}
export TPCC_MINUTES_OF_DURATION=${TPCC_MINUTES_OF_DURATION:-5}
export TPCC_TOTAL_ITERATIONS=${TPCC_TOTAL_ITERATIONS:-10000000}
export TPCC_INIT_MAX_WAIT_SECONDS=${TPCC_INIT_MAX_WAIT_SECONDS:-30}
export TPCC_TCL_SCRIPT_PATH=${TPCC_TCL_SCRIPT_PATH:-"/tcls"}
export TPCC_WAIT_COMPLETE_MILLSECONDS=${TPCC_WAIT_COMPLETE_MILLSECONDS:-5000}
### current supported algorithm: fixed, binary_search, advanced_binary_search
export TPCC_HAMMER_NUM_VIRTUAL_USERS_GEN_ALGORITHM=${TPCC_HAMMER_NUM_VIRTUAL_USERS_GEN_ALGORITHM:-"fixed"}
export TPCC_VUSERS_STEPS=${TPCC_VUSERS_STEPS:-4}
export TPCC_VUSERS_FLOAT_FACTOR=${TPCC_VUSERS_FLOAT_FACTOR:-0.1}
export TPCC_ASYNC_SCALE=${TPCC_ASYNC_SCALE:-false}
export TPCC_CONNECT_POOL=${TPCC_CONNECT_POOL:-false}
export TPCC_TIMEPROFILE=${TPCC_TIMEPROFILE:-false}


function scale_hammerdb_params_gated() {
    export TPCC_NUM_WAREHOUSES=2
    # Build virtual users must be less than or equal to number of warehouses
    export TPCC_THREADS_BUILD_SCHEMA=2
    export TPCC_HAMMER_NUM_VIRTUAL_USERS="2"
    export TPCC_MINUTES_OF_RAMPUP=1
    export TPCC_MINUTES_OF_DURATION=1
    export TPCC_RUNTIMER_SECONDS=300
}
