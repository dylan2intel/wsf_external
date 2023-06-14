#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if(" GNR DMR SPR SRF CWF EMR ICX " MATCHES " ${PLATFORM} ")

    add_workload("openssl3_rsamb_qatsw")

    string(REPLACE "_qatsw" "_sw" workload1 "${workload}")
    foreach(algo "rsa" "dsa" "ecdsa" "ecdh" "aes-sha" "aes-gcm")

        add_testcase(${workload}_${algo})
        add_testcase(${workload1}_${algo} "sw-${algo}")

    endforeach()

    add_testcase(${workload}_rsa_gated)

endif()

if(" SPR EMR " MATCHES " ${PLATFORM} ")

    add_workload("openssl3_rsamb_qathw")

    foreach(algo "rsa" "dsa" "ecdsa" "ecdh" "dh" "hkdf" "prf" "ecx" "chachapoly" "aes-sha" "aes-gcm")

        add_testcase(${workload}_${algo})

    endforeach()

     add_testcase(${workload}_rsa_gated)
     add_testcase(${workload}_rsa_pkm)

endif()
