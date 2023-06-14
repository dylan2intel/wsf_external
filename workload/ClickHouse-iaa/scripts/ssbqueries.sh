#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


# choose file between standard and gated
if [[ "${TESTCASE}" =~ ^test.*_gated$ ]]; then QUERIES_FILE="ssbqueries_gated.sql"; else QUERIES_FILE="ssbqueries.sql"; fi
TRIES=3

CLICKHOUSE_CLIENT="clickhouse client -h 127.0.0.1"
# localhost for docker, service IP for k8s
if [ "$BACKEND" = "kubernetes" ]; then CLICKHOUSE_CLIENT="clickhouse client -h ${CLICKHOUSE_IAA_SERVICE_HOST}"; fi

echo "Clickhouse query latency in seconds:"
cat "$QUERIES_FILE" | while read query; do
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null

    echo -n "${query} "
    echo -n "["
    for i in $(seq 1 $TRIES); do
        RES=$(${CLICKHOUSE_CLIENT} --time --format=Null --max_memory_usage=100G --query="$query" 2>&1)
        [[ "$?" == "0" ]] && echo -n "${RES}" || echo -n "null"
        [[ "$i" != $TRIES ]] && echo -n ","
    done
    echo "]"
done

