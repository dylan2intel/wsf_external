#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels:
    {}
ifelse(index(TESTCASE,_3n),-1,,`loop(`i', `0', BROKER_SERVER_NUM, `dnl
- labels:
    {}
')')
