#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
ifelse(index(WORKLOAD,`_qathw'),-1,`dnl
- labels: {}
',`dnl
- labels:
    HAS-SETUP-QAT-V200: required
    HAS-SETUP-HUGEPAGE-2048kB-4096: required
')
