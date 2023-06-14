#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:

ifelse("defn(`CLUSTERNODES')","1",`dnl
- labels: {}
',`dnl
- labels:
    HAS-SETUP-STORAGE: "required"
- labels:
    HAS-SETUP-SMART-SCIENCE-LAB: "required"
')dnl