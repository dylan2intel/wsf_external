#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Generate multiple Dockerfiles 

list(APPEND jdk_variant openjdk zulu)

if(" ICX SPR " MATCHES " ${PLATFORM} ")

    file(GLOB customers "configs/*/*.cmake")
    foreach(customer ${customers})
        include(${customer})
    endforeach()
endif()
