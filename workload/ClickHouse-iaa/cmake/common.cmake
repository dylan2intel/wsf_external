add_workload("clickhouse_iaa")
add_testcase(${workload}_hardware_benchmark "hardware_benchmark")
add_testcase(${workload}_hardware_benchmark_pkm "hardware_benchmark_pkm")
add_testcase(${workload}_hardware_benchmark_gated "hardware_benchmark_gated")
