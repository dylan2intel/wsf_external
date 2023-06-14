#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKLOAD=${WORKLOAD:-cm_xapp}

CMXAPPRUNTIME=${INITIATIONTIME:-1080}
INITIATIONTIME=${INITIATIONTIME:-120}
CELLINDLIMIT=${CELLINDLIMIT:-1000}
PARALLELLOOP=${PARALLELLOOP:-true}
QVALUE=${QVALUE:-10}
PREPROCESSING=${PREPROCESSING:-false}
COREBIND=${COREBIND:-0}

BENCHMARK_TYPE=$(echo ${OPTION}|cut -d_ -f1)
SCALE_FACTOR=$(echo ${OPTION}|cut -d_ -f2)

if [[ $SCALE_FACTOR == "gated" ]]
then
  CMXAPPRUNTIME=120
  INITIATIONTIME=60
fi
if [[ $SCALE_FACTOR == "pkm" ]]
then
  CMXAPPRUNTIME=1080
  INITIATIONTIME=120
fi

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

# Workload Settings
WORKLOAD_PARAMS=(INITIATIONTIME CELLINDLIMIT PARALLELLOOP QVALUE PREPROCESSING COREBIND)
TIMEOUT=36000

# Docker Setting
DOCKER_IMAGE=""
DOCKER_OPTIONS=""

# Kubernetes Setting
HELM_CHART_VER="v5"
HELM_CHART_REPO="https://af01p-igk.devtools.intel.com/artifactory/platform_hero-igk-local/Edge/cm-xapp/cm-xapp-charts-${HELM_CHART_VER}.tar.gz"
wget --no-proxy -T 5 --tries=inf -O - ${HELM_CHART_REPO} | tar -zxv -C $DIR/helm

JOB_FILTER="job-name=cm-xapp"
HELM_OPTIONS="--set parameters.xAppRunTime=$CMXAPPRUNTIME \
--set parameters.initiationTime=$INITIATIONTIME \
--set parameters.cellIndLimit=$CELLINDLIMIT \
--set parameters.parallelLoop=$PARALLELLOOP \
--set parameters.qValue=$QVALUE \
--set parameters.preprocessing=$PREPROCESSING \
--set parameters.corebind=$COREBIND"

. "$DIR/../../script/validate.sh"

