#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    foreach(MONGOVER 441 )
        add_stack("mongodb${MONGOVER}_base")
        add_testcase(${stack}_mongodb_sanity)
    endforeach()
endif()
