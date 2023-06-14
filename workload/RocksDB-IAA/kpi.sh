#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
type=${1:-readrandomwriterandom}

awk -v type=$type '
BEGIN {
    r_p50=0
    r_p95=0
    r_p99=0
    w_p50=0
    w_p95=0
    w_p99=0
    micros_op=0
    ops_sec=0
}


/^'"$type"'/ {
    micros_op = $3
    ops_sec = $5
}


/^rocksdb.db.get.micros/ {
    r_p50=$4
    r_p95=$7
    r_p99=$10
}

/^rocksdb.db.write.micros/ {
    w_p50=$4
    w_p95=$7
    w_p99=$10
}

END {
    print "*throughputS: "ops_sec
    print "Read-P99: "r_p99
}
' */output*.logs 2>/dev/null || true