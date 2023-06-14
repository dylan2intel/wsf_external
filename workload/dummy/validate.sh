#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details. 

# define the workload arguments
SCALE=${1:-1}
RETURN_VALUE=${2:-0}
SLEEP_TIME=${3:-0}

# Logs Setting
  # DIR is the workload script directory. When validate.sh is executed, the 
  # current directory is usually the logs directory. 
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
  # This script allows the user to overwrite any environment variables, given 
  # a TEST_CONFIG yaml configuration. See doc/ctest.md for details. 
. "$DIR/../../script/overwrite.sh"

# Workload Setting
  # The workload parameters will be saved to the cumulus dashboard. Specify 
  # an array of configuration parameters as environmental scalars. 
WORKLOAD_PARAMS=(SCALE RETURN_VALUE SLEEP_TIME)

  # Workload tags can be used to track Intel values across multple versions 
  # of workload implementations. See doc/intel-values.md for details.  
#WORKLOAD_TAGS="BC-BASELINE"

# Docker Setting
  # if the workload does not support docker run, leave DOCKER_IMAGE empty. 
  # Otherwise, specify the image name and the docker run options.
DOCKER_IMAGE="$DIR/Dockerfile"
DOCKER_OPTIONS="-e SCALE=$SCALE -e RETURN_VALUE=$RETURN_VALUE -e SLEEP_TIME=$SLEEP_TIME"

# Kubernetes Setting
  # You can alternatively specify HELM_CONFIG and HELM_OPTIONS
RECONFIG_OPTIONS="-DSCALE=$SCALE -DRETURN_VALUE=$RETURN_VALUE -DSLEEP_TIME=$SLEEP_TIME"
JOB_FILTER="job-name=dummy-benchmark"

# kpi args
SCRIPT_ARGS="${SCALE}"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"

