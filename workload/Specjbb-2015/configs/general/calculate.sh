#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# ######################################
# Interface Script that configure's Specjbb JVM and threading arguments depending on input configuration
# Globals:
#   None
# Arguments:
#   None
# Example:
#  . ./calculate.sh
# Return:
# 	0 if successfully context'ed
# ######################################

# ######################################
# Generates the JVM Options for each of the Specjbb services
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   None
# Return:
# 	 Pipe delimited JVM options for TI|CT|BE
#    Empty use caller values
# ######################################
function get_jvm_options() {
    # Use default (from caller)
    echo ""
}

# ######################################
# Calculate Tier1|2|3 threads for specjbb
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#    None
# Return:
# 	 Pipe delimited JVM options for [tier_1_threads|tier_2_threads|tier_3_threads]
#    Empty use caller values
# ######################################
function get_specjbb_tier_threads() {
    # Use default (from caller)
    echo ""
}

# ######################################
# Generates specjbb gc threads
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   platform                        ICX|SPR ....
#   user_configured_gc_threads      user inputted gc threads
# Return:
# 	gc threads for specjbb
# ######################################
function get_specjbb_gc_threads() {
    platform=$1
    user_configured_gc_threads=$2

    if [[ "${platform}" =~ ^(ICX)$ ]]; then
        cores_per_socket=$(lscpu | grep "Core(s) per socket:" | awk -F ':' '{print $2}')
        threads=$((cores_per_socket / SPECJBB_GROUPS))
        echo "${user_configured_gc_threads:-$threads}"
    elif [[ "${platform}" =~ ^(SPR)$ ]]; then
        vCPUs=$(grep -c ^processor /proc/cpuinfo)
        threads=$((vCPUs / SPECJBB_GROUPS))
        echo "${user_configured_gc_threads:-$threads}"
    else
        vCPUs=$(grep -c ^processor /proc/cpuinfo)
        threads=$((vCPUs / SPECJBB_GROUPS))
        echo "${user_configured_gc_threads:-$threads}"
    fi
}

# ######################################
# Get Specjbb Groups
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   platform                        ICX|SPR ....
#   user_configured_gc_threads      user inputted gc threads
# Return:
# 	Number of groups to run specjbb with. Correlation between number of BE services and number of groups
# ######################################
function get_specjbb_groups() {
    echo "${SPECJBB_GROUPS:-${NUMA_NODES}}"
}

# ######################################
# Get Backend Heap configuration
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   cpus_per_group
#   user_configured_gc_threads      user inputted gc threads
# Return:
# 	Pipe delimited [xmx|xms|xmn] value to be injected into the backend specjbb service
# ######################################
function get_specjbb_backend_heap_sizes() {
    cpus_per_group=$1

    execution_type=$(echo "${SPECJBB_WORKLOAD_CONFIG}" | awk -F '_' '{print $2}')

    # Tune for critialJOPs (use as much memory as possible for particular machine setup to get best possible results)
    if [ "$execution_type" == "crit" ]; then

        multipler=1
        unit=g              # default, use Gigabytes as configuration unless user has inputted Mb for any heap/controller configuration

        IFS='|' read -r i_unit injector_heap < <(get_heap_configuration "Xms" "${SPECJBB_INJECTOR_HEAP_MEMORY}")
        IFS='|' read -r c_unit controller_heap < <(get_heap_configuration "Xms" "${SPECJBB_CONTROLLER_HEAP_MEMORY}")

        # Use same unit for all calcuations, default Giga unless user specifies Mega in any case
        if [[ "$i_unit" =~ (m|M) || "$c_unit" =~ (m|M) ]]; then
            multipler=1024
            unit=m

            [[ "$i_unit" =~ (m|M) || "$c_unit" =~ (g|G) ]] && controller_heap=$(( controller_heap * multipler ))
            [[ "$i_unit" =~ (g|G) || "$c_unit" =~ (m|M) ]] && injector_heap=$(( injector_heap * multipler ))
        fi

        total_free_mem_gb=$(get_free_memory_gb)
        total_free_mem=$(( total_free_mem_gb * multipler))

        # leave 10% memory left over for machines < 64Gb to run other tasks
        available_memory_left_over=$(echo "${total_free_mem_gb}*0.1" | bc -l)
        if [ "${total_free_mem_gb}" -ge 64 ]; then

            # otherwise leave 7Gb left over for higher-spec machines
            available_memory_left_over=7
        fi

        available_memory_left_over=$(echo "${available_memory_left_over}*${multipler}" | bc -l)

        # Calculate Backend Heap memory
        total_injector_mem=$(( SPECJBB_GROUPS * injector_heap ))
        available_backend_mem=$(echo "(${total_free_mem} - ${total_injector_mem} - ${controller_heap} - ${available_memory_left_over})" | bc -l)
        specjbb_backend_heap=$(echo "(${available_backend_mem}/${SPECJBB_GROUPS})" | bc)

        if [ "${available_backend_mem:-0}" -le 8 ]; then
            echo "There is no availabe memory left in the system. Check if another job is running on the machine!" >&2
        fi

        # Adjusts memory sizes between 32GB and 48GB as these are problematic due to Java Compressed OOPS.
        limit_32_gb=$(( 32 * multipler ))
        limit_48_gb=$(( 48 * multipler ))
        if (((specjbb_backend_heap >= limit_32_gb) && (specjbb_backend_heap <= limit_48_gb))); then
            specjbb_backend_heap=$(( 31 * multipler ))
        fi

        # divide by 1 to round down
        xmn_difference=$(( 2 * multipler ))  # 2 Gb
        backend_xmn=$(echo "(${specjbb_backend_heap}-${xmn_difference})/1" | bc)
        echo "${specjbb_backend_heap}${unit}|${specjbb_backend_heap}${unit}|${backend_xmn}${unit}"

        # Otherwise tune for maxJOps
    elif [ "${SPECJBB_TUNE_OPTION:-regular}" == "max" ]; then
        baseline_memory=$((cpus_per_group * SPECJBB_MEMORY_PER_CORE))

        # Adjusts memory sizes between 32GB and 48GB as these are problematic due to Java Compressed OOPS.
        if (((baseline_memory >= 32) && (baseline_memory <= 48))); then
            baseline_memory=31
        fi

        calculated_xmn=$((baseline_memory - 2))
        if [[ ${calculated_xmn} -le 1 ]]; then
            calculated_xmn=1
        fi

        echo "${baseline_memory}g|${baseline_memory}g|${calculated_xmn}g"
    else
        xmx="${SPECJBB_XMX:-4g}"
        xms="${SPECJBB_XMX:-4g}"

        specjbb_xmx=$(echo "${xmx}" | grep -Po "[0-9]{1,}")
        xmn="${SPECJBB_XMN:-$((specjbb_xmx - 2))g}"

        echo "${xmx}|${xms}|${xmn}"
    fi
}

# ######################################
# Get heap metrics for heap configuration
# Globals:
#   None
# Arguments:
#   $1 extact_key             @example Xms|Xmn|Xmx
#   $2 heap_configuration     @example -Xms2g -Xmx2g -Xmn1536m
# Notes: local private
# ######################################
get_heap_configuration() {
    extract_key="$1"
    heap_configuration="$2"

    extracted_key=$(echo "$heap_configuration" | grep -Po "${extract_key}[^ ]+")
    extracted_key_value=$(echo "$extracted_key" | grep -Po "[0-9]+")
    extracted_key_metric=$(echo "$extracted_key" | grep -Po "(m|M|g|G)$")

    if [[ ! "${extracted_key_metric}" =~ (g|G|m|M) ]]; then
        echo >&2 "Unsupported heap metric: $extracted_key_metric input:$2"
        exit 1
    fi

    echo "${extracted_key_metric}|${extracted_key_value}"
}

# ######################################
# Get Backend Heap configuration
# Globals:
#   SPECJBB_USE_HUGE_PAGES      whether static huge pages are configured or not. Free memory will be taken from here if enabled
# Arguments:
#   None
# Return:
# 	Total currently available free memory on the machine
# Notes: local private
# ######################################
function get_free_memory_gb() {

	# Configured with huge pages on ==> calculate free memory based on huge page setup
	if [ "${SPECJBB_USE_HUGE_PAGES}" == "true" ]; then
		read -r h_free h_size < <(grep -iP "HugePages_Free|Hugepagesize" /proc/meminfo | sort -n | grep -Po "[0-9]+" | tr "\n" " ")

		divide_by=1			                # default is 1048576 (1Gb)
		if [ "${h_size}" -eq 2048 ]; then
			divide_by=512
		fi

        if [ "${h_free}" -eq 0 ]; then
            echo "You have configured SPECJBB_USE_HUGE_PAGES=true, but there are no hugepages configured to run the workload. Please ammend!" >&2
			total_free_gb=0
		fi

        total_free_gb=$(( h_free / divide_by ))
        if [ "${total_free_gb}" -le 32 ]; then
            echo "You have configured SPECJBB_USE_HUGE_PAGES=true, but there the number of free pages configured:${total_free_gb}Gi is very low and will likey result in the workload being aborted durning its run!" >&2
		fi

	else
		total_free_kb=$(grep "MemFree" /proc/meminfo | grep -Po "[0-9]+")
		total_free_gb=$(( total_free_kb / ( 1024 ** 2 ) ))
	fi

	echo "${total_free_gb}"
}