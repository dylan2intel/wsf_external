#!/bin/bash

./enable_4iaa.sh
clickhouse server --config-file=/etc/clickhouse-server/config.xml >&/root/server.log& >/dev/null
sleep 3

./ssbclient.sh
