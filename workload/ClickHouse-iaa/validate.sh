#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details. 

# define the workload name and arguments
WORKLOAD=${WORKLOAD:-clickhouse_iaa}
TESTCASE=${TESTCASE:-hardware_benchmark}

# Logs Setting. 
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
  # This script allows the user to overwrite any environment variables, given a 
  # TEST_CONFIG yaml configuration. See doc/ctest.md for details. 
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(WORKLOAD)

# Docker Setting
  # if the workload does not support docker run, leave DOCKER_IMAGE empty. Otherwise
  # specify the image name and the docker run options.
DOCKER_IMAGE="clickhouse-iaa-ssb"
DOCKER_OPTIONS="--privileged -v /dev:/dev --network host -e TESTCASE=$TESTCASE"

# Kubernetes Setting
# You can alternatively specify HELM_CONFIG and HELM_OPTIONS
RECONFIG_OPTIONS="-DWORKLOAD=$WORKLOAD -DBACKEND=kubernetes -DTESTCASE=$TESTCASE"
JOB_FILTER="job-name=clickhouse-iaa-benchmark"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"
