#!/bin/sh -e

# This dummy workload calculates the PI sequence. with workload-specific custom scale,return_value and sleep_time params

time -p sh -c "echo \"scale=${SCALE:-20}; 4*a(1)\" | bc -l; sleep ${SLEEP_TIME:-0}"
exit ${RETURN_VALUE:-0}

