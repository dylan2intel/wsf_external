#!/bin/bash

CLICKHOUSE_CLIENT="clickhouse client -h 127.0.0.1"
# localhost for docker, service IP for k8s
if [ "$BACKEND" = "kubernetes" ]; then CLICKHOUSE_CLIENT="clickhouse client -h ${CLICKHOUSE_IAA_SERVICE_HOST}"; fi

cat ./tablegen.sql | while read query; do
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
    echo "${query} "
    ${CLICKHOUSE_CLIENT} --max_memory_usage=100G --query="$query" 2>&1
done
${CLICKHOUSE_CLIENT} --max_memory_usage=100G --query "INSERT INTO customer FORMAT CSV" < ./ssb-dbgen/customer.tbl
${CLICKHOUSE_CLIENT} --max_memory_usage=100G --query "INSERT INTO part FORMAT CSV" < ./ssb-dbgen/part.tbl
${CLICKHOUSE_CLIENT} --max_memory_usage=100G --query "INSERT INTO supplier FORMAT CSV" < ./ssb-dbgen/supplier.tbl
${CLICKHOUSE_CLIENT} --max_memory_usage=100G --query "INSERT INTO lineorder FORMAT CSV" < ./ssb-dbgen/lineorder.tbl
cat ./tableconvert.sql | while read query; do
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
    echo "${query} "
    ${CLICKHOUSE_CLIENT} --max_memory_usage=100G --query="$query" 2>&1
done

./ssbqueries.sh
