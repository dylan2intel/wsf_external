#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload(db_bench_rocksdbiaa)
add_testcase(${workload}_readrandom_pkm readrandom)
add_testcase(${workload}_randomreadrandomwrite_pkm readrandomwriterandom)
add_testcase(${workload}_readrandom_gated readrandom)
add_testcase(${workload}_zstd_readrandom_pkm zstd_readrandom)