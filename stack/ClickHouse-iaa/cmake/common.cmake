#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_stack("clickhouse_iaa_base")
add_testcase(${stack}_is_server_up default)
