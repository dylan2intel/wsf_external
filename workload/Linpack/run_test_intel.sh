#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
N_SIZE=${N_SIZE:-auto}
ASM=${ASM:-default_instruction}

Sockets=$(lscpu | awk '/Socket\(s\):/{print $NF}')
Numas=$(lscpu | awk '/NUMA node\(s\):/{print $NF}')

cd /opt/intel/mkl/benchmarks/mp_linpack
source /opt/intel/oneapi/setvars.sh

if [[ $ASM == "avx2" ]]; then
    NB=192
elif [[ $ASM == "sse" ]]; then
    NB=256
else
    NB=384
fi

PValue=$Sockets
QValue=$(( $Numas / $Sockets ))

if [ $N_SIZE == "auto" ]; then
    total_numa_nodes=$(lscpu | grep -c "NUMA node.* CPU(s):")
    snc4_numa_nodes=$(( Sockets * 4 ))
    snc2_numa_nodes=$(( Sockets * 2 ))

    mem=$(free -b | awk '/Mem:/{print $2}')
    problem_size=$(echo "sqrt(0.8 * $mem / 8)" | bc)

    if [[ $ASM == "avx2" ]]; then
        problem_size=$((problem_size*1/2))
    elif [[ $ASM == "avx3" ]]; then
        problem_size=$((problem_size*3/4))
    elif [[ $ASM == "sse" ]]; then
        problem_size=$((problem_size*1/4))
    else
        echo -e "\nWarning: No ASM information provided. Setting asm=avx3\n"
        problem_size=$((problem_size*3/4))
    fi

    echo "Using this problem size $problem_size"
    sed -i 's|MPI_PROC_NUM=2|MPI_PROC_NUM='"$Numas"'|g' runme_intel64_dynamic
    ./runme_intel64_dynamic -p $PValue -q $QValue -b $NB -n $problem_size

else
    echo "Using this problem size $N_SIZE"
    sed -i 's|MPI_PROC_NUM=2|MPI_PROC_NUM='"$Numas"'|g' runme_intel64_dynamic
    ./runme_intel64_dynamic -p $PValue -q $QValue -b $NB -n $N_SIZE
fi