#!/bin/bash

# The kpi.sh must be self-contained (without using any external script with the 
# exception of commonly available shell scripts and gawk). 

# The kpi.sh script can take arguments, defined by SCRIPT_ARGS in validate.sh. 
# See doc/kpi.sh.md and doc/validate.sh.md for full documentation. 

gawk -F";" '

# For hardware_benchmark
# Calculate geometric mean for cold and hot cache + total latency
/Clickhouse query latency in seconds:/ {

    no_of_queries=0
    total_latency=0
    total_cold_cache_latency=1
    total_hot_cache_latency=1

    while (getline) {
        
        if ($2~/\[[0-9]+\.[0-9]+,[0-9]+\.[0-9]+,[0-9]+\.[0-9]+\]/) {

            no_of_queries+=1
            # Parse values from latency array
            split($2, seps, /[0-9]+\.[0-9]+/, values)
            
            # First run for every query is with cold cache
            total_cold_cache_latency *= values[1]

            # All the other are with hot cache
            total_hot_cache_latency *= values[2] * values[3]
        }
    }

    total_latency = total_cold_cache_latency * total_hot_cache_latency
    print "*Geomean query latency (s): " total_latency ^ (1 / (3 * no_of_queries))
    print "Cold cache geomean query latency (s): " total_cold_cache_latency ^ (1 / no_of_queries)
    print "Hot cache geomean query latency (s): " total_hot_cache_latency ^ (1 / (2 * no_of_queries))
}

' */output.logs 2>/dev/null || true
