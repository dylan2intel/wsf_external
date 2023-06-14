#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

./enable_4iaa.sh
clickhouse server --config-file=/etc/clickhouse-server/config.xml >&/root/server.log& >/dev/null
sleep 3

./ssbclient.sh
