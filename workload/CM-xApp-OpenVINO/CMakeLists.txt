#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if(" GNR SPR EMR ICX " MATCHES " ${PLATFORM} ")
    add_workload("cm_xapp")

    
    foreach (option "openvino" "openvino_pkm" "openvino_gated" )
        add_testcase(${workload}_${option} "${option}")

    endforeach()

endif()
