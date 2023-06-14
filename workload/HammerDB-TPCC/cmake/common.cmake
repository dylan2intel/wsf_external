#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload(hammerdb_tpcc_mysql8031_base)
add_testcase(${workload}_disk_hugepage_off_gated "mysql" "disk" "off" "8031" "base")
add_testcase(${workload}_disk_hugepage_off_pkm "mysql" "disk" "off" "8031" "base")
add_testcase(${workload}_disk_hugepage_off "mysql" "disk" "off" "8031" "base")
add_testcase(${workload}_disk_hugepage_on "mysql" "disk" "on" "8031" "base")
