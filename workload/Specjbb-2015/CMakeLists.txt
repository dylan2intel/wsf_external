# Generate multiple Dockerfiles 

list(APPEND jdk_variant openjdk zulu)

if(" SRF ICX SPR GNR ARMv8 ARMv9 MILAN ROME GENOA " MATCHES " ${PLATFORM} ")

    file(GLOB customers "configs/*/*.cmake")
    foreach(customer ${customers})
        include(${customer})
    endforeach()
endif()
