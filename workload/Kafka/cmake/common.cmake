if (NOT BACKEND STREQUAL "docker")
    foreach(JDKVER 17 11 8)
        add_workload("kafka_jdk${JDKVER}")
        add_testcase(${workload}_gated gated)
        add_testcase(${workload}_1n default)
        add_testcase(${workload}_3n default)
        add_testcase(${workload}_3n_pkm default)
    endforeach()
endif()
