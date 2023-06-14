#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_stack("rocksdb")
add_testcase(${stack}_readrandom_hw_test readrandom hw)
add_testcase(${stack}_readrandom_sw_test readrandom sw)
add_testcase(${stack}_fillseq_hw_test fillseq hw)
add_testcase(${stack}_fillseq_sw_test fillseq sw)
add_testcase(${stack}_readrandomwriterandom_hw_test readrandomwriterandom hw)
add_testcase(${stack}_readrandomwriterandom_sw_test readrandomwriterandom sw)