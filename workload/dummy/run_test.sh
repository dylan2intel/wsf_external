#!/bin/sh -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# This dummy workload calculates the PI sequence. with workload-specific custom scale,return_value and sleep_time params

time -p sh -c "echo \"scale=${SCALE:-20}; 4*a(1)\" | bc -l; sleep ${SLEEP_TIME:-0}"
exit ${RETURN_VALUE:-0}

