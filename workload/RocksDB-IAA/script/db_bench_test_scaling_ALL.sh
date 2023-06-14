#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
#------------------------------------------------------------------------------
# INTEL CONFIDENTIAL
# Copyright 2021 Intel Corporation All Rights Reserved.
#
# The source code contained or described herein and all documents related to the
# source code ("Material") are owned by Intel Corporation or its suppliers or
# licensors. Title to the Material remains with Intel Corporation or its
# suppliers and licensors. The Material contains trade secrets and proprietary
# and confidential information of Intel or its suppliers and licensors. The
# Material is protected by worldwide nCopyright and trade secret laws and treaty
# provisions. No part of the Material may be used, copied, reproduced, modified,
# published, uploaded, posted, transmitted, distributed, or disclosed in any way
# without Intel's prior express written permission.
#
# No license under any patent, nCopyright, trade secret or other intellectual
# property right is granted to or conferred upon you by disclosure or delivery
# of the Materials, either expressly, by implication, inducement, estoppel or
# otherwise. Any license under such intellectual property rights must be express
# and approved by Intel in writing.
#------------------------------------------------------------------------------

# RocksDB performance testing.
# Luca Giacchino (luca.giacchino@intel.com)
export  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
#Input
comp=$1 #options: iaa, zstd, zlib, lz4, none
iaa_inst=$2 #options: 0 (if sw de/compression), 1, 2, 4, 8
iaa_wq_size=$3 #options: 1-128
data_pattern=$4 #options: readrandom, readrandomwriterandom
keysz_input=$5 #options: 4, 16
valsz_input=$6 #options: 32, 256
blocksz_input=$7 #options: 4, 8, 16
cpu_input=($8) #options: '4 7 14 21 28 30 32 35 42 48 49 56 60 64'
num_sockets=$9 #options: 1, 2, 4
ht=${10} #options: y, n
source_data=${11} #options: default, calgary
collect_perf=${12} #options: y, n
collect_emon=${13} #options: y, n
collect_memcomp=${14} #options: y, n

for var in comp iaa_inst iaa_wq_size data_pattern keysz_input valsz_input blocksz_input cpu_input num_sockets ht source_data collect_perf collect_emon collect_memcomp
do
    echo "$var:" "${!var}"
done
#zstd --version

#check inputs
input_error="echo -e \"\n
   USAGE: ./db_bench_test_scaling_ALL.sh compression_type iaa_instances data_pattern key_size value_size cpu_list\n
	   compression_type: iaa, zstd, zlib, lz4, none\n
	   iaa_instances: 0, 1, 2, 4, 8\n
	   iaa_wq_size: 1-128\n
	   data_pattern: readrandom, readrandomwriterandom\n
	   key_size: 4, 8, 16\n
	   value_size: 32, 256\n
	   block_size: 4, 8, 16\n
	   cpu_list: '4 7 14 21 28 30 32 35 42 48 49 56 60 64'\n
	   num_sockets: 1, 2, 4 (SNC not supported)\n
     hyperthreading: y,n\n
	   source_data: default, calgary\n
	   collect_perf: y,n\n
	   collect_emon: y,n\n
	   collect_memcomp: y,n\n
   example: ./db_bench_test_scaling_ALL.sh iaa 4 128 readrandomwriterandom 16 256 '4 7 42 56' 1 calgary y y n \n\n \"; exit 1"
if [ "$#" -ne 14 ]; then
  echo "Illegal number of parameters"
  eval $input_error
fi
case $comp in iaa|zlib|zstd|lz4|none) true ;; *) echo "$comp - Check compression_type"; eval $input_error ;; esac
case $iaa_inst in 0|1|2|4|8) true ;; *) echo "$iaa_inst - Check iaa_instances"; eval $input_error ;; esac
case $data_pattern in readrandom|readrandomwriterandom) true ;; *) echo "$data_pattern - Check data_pattern"; eval $input_error ;; esac
case $keysz_input in 4|8|16) true ;; *) echo "$keysz_input - Check key_size"; eval $input_error ;; esac
case $valsz_input in 32|256) true ;; *) echo "$valsz_input - Check value_size"; eval $input_error ;; esac
case $blocksz_input in 4|8|16) true ;; *) echo "$blocksz_input - Check block_size"; eval $input_error ;; esac
for i in ${!cpu_input[@]}
do
  case ${cpu_input[i]} in 4|7|14|21|28|30|32|35|42|48|49|56|60|64) true ;; *) echo "${cpu_input[i]} - Check cpu_list"; eval $input_error ;; esac
done
case $num_sockets in 1|2|4) true ;; *) echo "$num_sockets - Check num_sockets"; eval $input_error ;; esac
case $ht in y|n) true ;; *) echo "$ht - Check hyperthreading"; eval $input_error ;; esac
case $source_data in default|calgary) true ;; *) echo "$source_data - Check source_data"; eval $input_error ;; esac
case $collect_perf in y|n) true ;; *) echo "$collect_perf - Check collect_perf"; eval $input_error ;; esac
case $collect_emon in y|n) true ;; *) echo "$collect_emon - Check collect_emon"; eval $input_error ;; esac
case $collect_memcomp in y|n) true ;; *) echo "$collect_memcomp - Check collect_memcomp"; eval $input_error ;; esac

# Directories
install_folder="/rocksdb"
rocksdb_folder=$install_folder"/rocksdb"          # folder containing RocksDB/db_bench executable
if [[ $comp == "iaa" ]]; then
  comp_name="com.intel.iaa_compressor_rocksdb"
  export base_data_folder=$install_folder"/rocksdb_data/${blocksz_input}kB_${valsz_input}B_${data_pattern}_scaling_${comp}${iaa_inst}_wq${iaa_wq_size}_${num_sockets}socket_${ht}ht"   # folder for data output
else
  comp_name=$comp
  export base_data_folder=$install_folder"/rocksdb_data/${blocksz_input}kB_${valsz_input}B_${data_pattern}_scaling_${comp}_${num_sockets}socket_${ht}ht"   # folder for data output
fi

echo $base_data_folder
mkdir -p $base_data_folder
app_folder=$install_folder                        # folder where data collection applications (PAT, flame graphs...) are installed
src=$PWD

# System configuration
numa_nodes=$num_sockets
cpus=("all" "all")                     # one entry per NUMA node. "all" uses all CPUs in the node. Specify CPU sets as accepted by numactl --physcpubind
nvme_drives=2

# Workload configuration - fixed
if [[ $ht == "y" ]]; then
  num_instances=$((4*num_sockets))
else
  num_instances=$((2*num_sockets))
fi
if [[ $data_pattern == "readrandomwriterandom" ]]; then
  num_instances=$(($num_instances*2))
fi
key_size="$keysz_input"
value_size="$valsz_input"
blksz=$((blocksz_input*1024))
ops=0                       # ops/thread
instance_ops=100000000      # ops/instance. If != 0, it overrides ops: ops = instance_ops/threads
if [[ $data_pattern == "readrandom" ]]; then
  duration=120                # If != 0, it overrides ops settings
elif [[ $data_pattern == "readrandomwriterandom" ]]; then
  duration=500
fi
bloom_bits=10
disable_wal=true
distribution=""           # empty for uniform. Example of non-uniform distribution: "--read_random_exp_range=10"
use_kmem=false

if [[ $value_size == 256 ]]; then
  entries=$((400000000*num_sockets/num_instances))  # entries/instance
else
  entries=$((2200000000*num_sockets/num_instances))
fi

value_src_data_file=""
value_src_data_type=""
if [[ $source_data == "calgary" ]]; then
  value_src_data_file=$install_folder/standard_calgary_corpus
  value_src_data_type="file_direct"
fi

# Workload configuration - by instance
# Use % as a placeholder for instance number. Use %% as a placeholder for node number. Use %%% as placeholder for nvme drive.
drive="/mnt/nvme%%%"
db=$drive"/rockstest%"                 # db path

# Workload configuration - by run

# Detect CPU number in NUMA nodes
num_numa_nodes=$(lscpu | grep -E "NUMA node\(s\)" | awk -F '[:]' '{print $2}' | tr -d " ")
node_start_core=()
node_start_ht=()
for (( n=0; n<$num_numa_nodes; n++ ));
do
  node_start_core+=($(lscpu | grep -E "NUMA node${n}" | awk -F '[:,-]' '{print $2}' | tr -d " "))
  if [[ $ht == "y" ]]; then
    node_start_ht+=($(lscpu | grep -E "NUMA node${n}" | awk -F '[:,-]' '{print $4}' | tr -d " "))
  fi
done

declare -A cpus_per_run_val
for i in "${cpu_input[@]}"
do
  if [[ $ht == "y" ]]; then
    for (( n=0; n<$numa_nodes; n++ ));
    do
      cpus_per_run_val[$i,$n]=${node_start_core[$n]}-$((${node_start_core[$n]}+$i-1)),${node_start_ht[$n]}-$((${node_start_ht[$n]}+$i-1))
    done
  else
    for (( n=0; n<$numa_nodes; n++ ));
    do
      cpus_per_run_val[$i,$n]=${node_start_core[$n]}-$((${node_start_core[$n]}+$i-1))
    done
  fi
done

#90% util
if [[ $data_pattern == "readrandom" ]]; then
  threads_per_inst[4]="2"
  threads_per_inst[7]="3"
  threads_per_inst[14]="6"
  threads_per_inst[21]="10"
  threads_per_inst[28]="13"
  threads_per_inst[30]="14"
  threads_per_inst[32]="15"
  threads_per_inst[35]="16"
  threads_per_inst[42]="19"
  threads_per_inst[48]="21"
  threads_per_inst[49]="22"
  threads_per_inst[56]="25"  # condition of main proof point
  threads_per_inst[60]="27"
  threads_per_inst[64]="29"
elif [[ $data_pattern == "readrandomwriterandom" ]]; then
  # TODO Due to double instances compared to readrandom, rounding is more of an issue is assigning threads per instance
  threads_per_inst[4]="1"
  threads_per_inst[7]="1"
  threads_per_inst[14]="3"
  threads_per_inst[21]="4"
  threads_per_inst[28]="5"
  threads_per_inst[30]="5"
  threads_per_inst[32]="6"
  threads_per_inst[35]="6"
  threads_per_inst[42]="8"
  threads_per_inst[48]="8"
  threads_per_inst[49]="9"
  threads_per_inst[56]="10"  # condition of main proof point
  threads_per_inst[60]="11"
  threads_per_inst[64]="12"
fi

#100% util (readrandom)
#threads_per_inst[4]="2"
#threads_per_inst[7]="3"
#threads_per_inst[14]="7"
#threads_per_inst[21]="10"
#threads_per_inst[28]="14"
#threads_per_inst[30]="15"
#threads_per_inst[32]="16"
#threads_per_inst[35]="17"
#threads_per_inst[42]="21"
#threads_per_inst[48]="24"
#threads_per_inst[49]="24"
#threads_per_inst[56]="28"
#threads_per_inst[60]="30"
#threads_per_inst[60]="32"

for i in "${cpu_input[@]}"
do
  totalthreads=$((threads_per_inst[$i]*num_instances))
  totalcpus=$((${i}*num_sockets))
  if [[ $comp == "iaa" ]]; then
    run_names+=("${comp}${iaa_inst}_${blocksz_input}kB_${value_size}B_fillseq_${totalthreads}t_${totalcpus}c" "${comp}${iaa_inst}_${blocksz_input}kB_${value_size}B_${data_pattern}_${totalthreads}t_${totalcpus}c")
  else
    run_names+=("${comp}_${blocksz_input}kB_${value_size}B_fillseq_${totalthreads}t_${totalcpus}c" "${comp}_${blocksz_input}kB_${value_size}B_${data_pattern}_${totalthreads}t_${totalcpus}c")
  fi
  cache_size+=(-1 -1) # in bytes
  compressed_cache_size+=(-1 -1) #in bytes
  cache_numshardbits+=(6 6)
  threads+=(1 "${threads_per_inst[$i]}") # threads/instance
  block_size+=("$blksz" "$blksz")
  use_cache_dcpmm_allocator+=("false" "false") # true/false
  use_direct_reads+=("false" "false")
  use_direct_io_for_flush_and_compaction+=("false" "false")
  compression+=("${comp_name}" "${comp_name}")
  prefill+=("c" "n") # y/n, or c (cleanup only). When selecting this option, prefill runs without data collection. To collect data during prefill, use fillseq workload.
  workloads+=("fillseq" "$data_pattern") # options: readrandom, readrandomwriterandom, readwhilewriting, fillseq (disable prefill)
  for w in {1..2}  # Duplicate for fillseq and readrandom/readrandomwriterandom
  do
    for (( n=0; n<$num_numa_nodes; n++ ));
    do
      cpus_per_run+=(${cpus_per_run_val[$i,$n]}) # if specified, it overrides cpus setting. For each run, need as many entries as numa nodes
    done
  done

  # Workload configuration - by instance/run
  # %-based placeholders enabled
  other_options_prefill+=("" "") # for example, block size need to match in run and prefill
  if [[ $comp == "iaa" ]]; then
    if [[ "$data_pattern" == "readrandom" ]]; then
      other_options_run+=("--max_background_jobs=60 --subcompactions=10 --compression_ratio=0.25 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0" \
                          "--compression_ratio=0.25 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0")
    elif [[ "$data_pattern" == "readrandomwriterandom" ]]; then
      other_options_run+=("--max_background_jobs=30 --subcompactions=5 --compression_ratio=0.25 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4" \
                          "--compression_ratio=0.25 --max_background_jobs=10 --subcompactions=5 --readwritepercent=80 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4")
    fi
  else
    if [[ "$data_pattern" == "readrandom" ]]; then
      other_options_run+=("--max_background_jobs=60 --subcompactions=10 --compression_ratio=0.25" \
                          "--compression_ratio=0.25")
    elif [[ "$data_pattern" == "readrandomwriterandom" ]]; then
      other_options_run+=("--max_background_jobs=30 --subcompactions=5 --compression_ratio=0.25 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4" \
                          "--compression_ratio=0.25 --max_background_jobs=10 --subcompactions=5 --readwritepercent=80 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4")
    fi
  fi
done

#print all runs and inputs
for j in run_names cache_size compressed_cache_size cache_numshardbits threads block_size use_cache_dcpmm_allocator use_direct_reads use_direct_io_for_flush_and_compaction compression prefill workloads cpus_per_run other_options_prefill other_options_run
do
        val1="echo \${!$j[@]}"
        echo -ne "$j = "
        for i in `eval ${val1}`; do val2="echo \${$j[$i]}"; echo -ne "[$i]`eval ${val2}` "; done
        echo -ne "\n"
done

# Data to collect
emon=$collect_emon        # collect EMON data (y/n)
sep="n"                   # collect SEP data (y/n)
pat="n"                   # collect PAT data (y/n)
flame_graph="n"           # collect flame graphs (y/n)
flame_graph_offcpu="n"    # collect off-cpu flame graphs (y/n)
vtune="n"                 # collect VTune (y/n)
perf_stat=$collect_perf   # collect perf stat (y/n)
memcomp_pmu=$collect_memcomp
custom_data="n"           # collect data with custom command (command specified in later section)
alone="n"                 # collect data with workload alone (y/n) - useful if restarting instances for each data collection

collect_memory="y"        # collect memory/disk usage snapshots during run
collect_offcpu="n"        # need bcc tools

post_process_only="n"     # only run post-processing. Assumes the data is already in the data folder.

# Data collection timing parameters
# Assumption is that run takes longer than delay+duration
restart_for_each_collection="n"  # "y": restart instances for each data collection. "n": run data collections sequentially without restarting instances.
emon_delay=10
emon_duration=30
emon_arch="intel"         # "intel" or "arm". For ARM, EMON-like data is collected with perf. Refer to https://intel.sharepoint.com/sites/EDPEmonDataProcessingTool/SitePages/EDP-GVT2.aspx
emon_driverless="n"
sep_delay=60
sep_duration=120
pat_delay=60
pat_duration=60
flame_delay=60
flame_duration=60
vtune_delay=60
vtune_duration=120
perf_stat_delay=5
perf_stat_duration1=10
perf_stat_duration2=10
memcomp_pmu_delay=5
memcomp_pmu_duration=30
custom_data_delay=60
cpu_util_delay=5
cpu_util_duration=30
collect_interval=60       # for memory/offcpu collection

# Data collection options
# db_bench stats
statistics="y"             # enable/disable statistics (y/n)
stats_interval_seconds=60  # every n seconds, report ops and ops/s for last interval and cumulative (for each thread). 0 to disable.
extra_interval_stats=1     # additional stats per interval. 0: disabled, 1:enabled
# emon
emon_file="/opt/intel/sep/config/edp/sapphirerapids_server_events_private.txt"  # emon event file on server
emon_folder="/opt/intel/sep"
emon_arm_folder=$app_folder/emon
edp_folder='C:\Users\lgiacchi\OneDrive - Intel Corporation\Desktop\EDP' # location of EDP software on system where post-processing is done (absolute path)
# flame graph
flame_graph_flamescope_data="n"     # keep perf script output to visualize in FlameScope
# vtune
vtune_folder="/opt/intel/vtune_profiler_2020.1.0.607630"
# perf
perf_stat_options="-e iax1/event=0x1,event_category=0x0/,iax1/event=0x2,event_category=0x0/,iax1/event=0x4,event_category=0x0/,iax1/event=0x8,event_category=0x0/,"
perf_stat_options+="iax1/event=0x1,event_category=0x1/,iax1/event=0x2,event_category=0x1/,iax1/event=0x40,event_category=0x1/,iax1/event=0x80,event_category=0x1/,"
perf_stat_options+="iax1/event=0x1,event_category=0x2/,iax1/event=0x2,event_category=0x2/,iax1/event=0x4,event_category=0x2/,iax1/event=0x8,event_category=0x2/,"

perf_stat_options+="iax3/event=0x1,event_category=0x0/,iax3/event=0x2,event_category=0x0/,iax3/event=0x4,event_category=0x0/,iax3/event=0x8,event_category=0x0/,"
perf_stat_options+="iax3/event=0x1,event_category=0x1/,iax3/event=0x2,event_category=0x1/,iax3/event=0x40,event_category=0x1/,iax3/event=0x80,event_category=0x1/,"
perf_stat_options+="iax3/event=0x1,event_category=0x2/,iax3/event=0x2,event_category=0x2/,iax3/event=0x4,event_category=0x2/,iax3/event=0x8,event_category=0x2/,"

perf_stat_options+="iax5/event=0x1,event_category=0x0/,iax5/event=0x2,event_category=0x0/,iax5/event=0x4,event_category=0x0/,iax5/event=0x8,event_category=0x0/,"
perf_stat_options+="iax5/event=0x1,event_category=0x1/,iax5/event=0x2,event_category=0x1/,iax5/event=0x40,event_category=0x1/,iax5/event=0x80,event_category=0x1/,"
perf_stat_options+="iax5/event=0x1,event_category=0x2/,iax5/event=0x2,event_category=0x2/,iax5/event=0x4,event_category=0x2/,iax5/event=0x8,event_category=0x2/,"

perf_stat_options+="iax7/event=0x1,event_category=0x0/,iax7/event=0x2,event_category=0x0/,iax7/event=0x4,event_category=0x0/,iax7/event=0x8,event_category=0x0/,"
perf_stat_options+="iax7/event=0x1,event_category=0x1/,iax7/event=0x2,event_category=0x1/,iax7/event=0x40,event_category=0x1/,iax7/event=0x80,event_category=0x1/,"
perf_stat_options+="iax7/event=0x1,event_category=0x2/,iax7/event=0x2,event_category=0x2/,iax7/event=0x4,event_category=0x2/,iax7/event=0x8,event_category=0x2/,"

perf_stat_options+="iax9/event=0x1,event_category=0x0/,iax9/event=0x2,event_category=0x0/,iax9/event=0x4,event_category=0x0/,iax9/event=0x8,event_category=0x0/,"
perf_stat_options+="iax9/event=0x1,event_category=0x1/,iax9/event=0x2,event_category=0x1/,iax9/event=0x40,event_category=0x1/,iax9/event=0x80,event_category=0x1/,"
perf_stat_options+="iax9/event=0x1,event_category=0x2/,iax9/event=0x2,event_category=0x2/,iax9/event=0x4,event_category=0x2/,iax9/event=0x8,event_category=0x2/,"

perf_stat_options+="iax11/event=0x1,event_category=0x0/,iax11/event=0x2,event_category=0x0/,iax11/event=0x4,event_category=0x0/,iax11/event=0x8,event_category=0x0/,"
perf_stat_options+="iax11/event=0x1,event_category=0x1/,iax11/event=0x2,event_category=0x1/,iax11/event=0x40,event_category=0x1/,iax11/event=0x80,event_category=0x1/,"
perf_stat_options+="iax11/event=0x1,event_category=0x2/,iax11/event=0x2,event_category=0x2/,iax11/event=0x4,event_category=0x2/,iax11/event=0x8,event_category=0x2/,"

perf_stat_options+="iax13/event=0x1,event_category=0x0/,iax13/event=0x2,event_category=0x0/,iax13/event=0x4,event_category=0x0/,iax13/event=0x8,event_category=0x0/,"
perf_stat_options+="iax13/event=0x1,event_category=0x1/,iax13/event=0x2,event_category=0x1/,iax13/event=0x40,event_category=0x1/,iax13/event=0x80,event_category=0x1/,"
perf_stat_options+="iax13/event=0x1,event_category=0x2/,iax13/event=0x2,event_category=0x2/,iax13/event=0x4,event_category=0x2/,iax13/event=0x8,event_category=0x2/,"

perf_stat_options+="iax15/event=0x1,event_category=0x0/,iax15/event=0x2,event_category=0x0/,iax15/event=0x4,event_category=0x0/,iax15/event=0x8,event_category=0x0/,"
perf_stat_options+="iax15/event=0x1,event_category=0x1/,iax15/event=0x2,event_category=0x1/,iax15/event=0x40,event_category=0x1/,iax15/event=0x80,event_category=0x1/,"
perf_stat_options+="iax15/event=0x1,event_category=0x2/,iax15/event=0x2,event_category=0x2/,iax15/event=0x4,event_category=0x2/,iax15/event=0x8,event_category=0x2/"  # e.g., "-T" for TSX counters
#memcomp-pmu
memcomp_dir="/home/nandhita/iax-memcomp/bin"
# custom data
custom_data_command=""
# bcc
bcc_folder="/usr/share/bcc/tools"   # typically /usr/share/bcc/tools on CentOS, /usr/sbin on Ubuntu
bcc_suffix=""                       # typically "" for CentOS, "-bpfcc" for Ubuntu (e.g., offcputime is offcputime-bpfcc)

# Start/end commands
# Run specified commands at start and end of each run. The output files are placed in the data directory for the run
start_command=""
start_command_output_file=""
end_command=""
end_command_output_file=""
# Run specified commands at the beginning of the script (before first run) and end (after last run)
if [[ $comp == "iaa" ]]; then
	init_command="/rocksdb/scripts/configure_iaa_user 0 1,$((2*iaa_inst-1)) ${iaa_wq_size}"
else
	init_command=""
fi
echo "init_command:" $init_command
final_command="cp -r $base_data_folder /mnt/nvme0"

#Summary options
summary_ops=true
summary_interval_ops=false
summary_block_cache_misses=false
summary_block_cache_hits=false
summary_block_cache_data_misses=false
summary_block_cache_data_hits=false
summary_block_cache_filter_misses=false
summary_block_cache_filter_hits=false
summary_block_cache_index_misses=false
summary_block_cache_index_hits=false
summary_compressed_block_cache_misses=false
summary_compressed_block_cache_hits=false
summary_p50_get_latency=true
summary_p99_get_latency=true
summary_p50_put_latency=true
summary_p99_put_latency=true
summary_p50_compression_nanos=true
summary_p50_decompression_nanos=true
summary_stall_micros=true

# Paired run summaries
# Assumes paired target vs baseline runs
# All arrays below must be same length (number of paired runs)
paired_run_names=()     # name of each paired run
baseline_runs=()        # indices of the baseline runs (indices in run_names array)
baseline_fill_runs=()   # indices of the runs to fill DB for baseline (indices in run_names array)
baseline_run_names=()   # name of each baseline run
target_runs=()          # indices of the target runs (indices in run_names array)
target_fill_runs=()     # indices of the runs to fill DB for target (indices in run_names array)
target_run_names=()     # name of each target run


function cleanup() {
  echo "Cleaning up"

  #rm -rf /mnt/nvme/rockstest # do not change this to a variable. If the variable is left empty, you will erase everything!
  rm -rf /mnt/nvme0/rockstest*
  rm -rf /mnt/nvme1/rockstest*
  rm -rf /mnt/nvme2/rockstest*
  rm -rf /mnt/nvme3/rockstest*

  sync; echo 3 > /proc/sys/vm/drop_caches
}


function prefill_instance() {
  local instance=$1
  local node=$2
  local nvme=$3
  local data_prefix=$4
  local run=$5

  replace_instance_node $db $instance $node $nvme
  db_instance=$replace_output

  replace_instance_node "${other_options_prefill[$run]}" $instance $node $nvme
  other_options_prefill_instance=$replace_output

  value_src_data_str=""
  if [[ $value_src_data_file != "" ]]; then
     value_src_data_str="--value_src_data_type=$value_src_data_type --value_src_data_file=$value_src_data_file"
  fi

  echo "Launching prefill instance:"$instance" node:"$node" nvme:"$nvme

  numactl --cpunodebind=$node --membind=$node $rocksdb_folder/db_bench --benchmarks="fillseq,stats" --statistics --db=$db_instance \
    --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} $other_options_prefill_instance \
    --disable_wal=$disable_wal \
    &> $data_folder/prefill_stats_${data_prefix}_${instance}.txt &
}


db_instances=()  # directories where DB is stored for each instance
function run_instance() {
  local instance=$1
  local node=$2
  local nvme=$3
  local data_prefix=$4
  local run=$5

  replace_instance_node $db $instance $node $nvme
  db_instance=$replace_output
  db_instances[$instance]=$db_instance

  replace_instance_node "${other_options_run[$run]}" $instance $node $nvme
  other_options_run_instance=$replace_output

  calculate_memnode $node
  memnode=$memnode_output

  numactl_cpu="--cpunodebind=$node"
  if [[ ${#cpus_per_run} -gt 0 ]]; then
    numactl_cpu="--physcpubind=${cpus_per_run[$((numa_nodes*run+node))]}"
  elif [[ ${cpus[$node]} != "all" ]]; then
    numactl_cpu="--physcpubind=${cpus[$node]}"
  fi

  if [[ $instance_ops -gt 0 ]]; then
    ops=$(($instance_ops/${threads[$run]}))
  fi

  duration_str=""
  if [[ $duration -gt 0 ]]; then
    duration_str="--duration="$duration
  fi

  statistics_str=""
  if [[ $statistics == "y" ]]; then
    statistics_str="--statistics"
  fi

  value_src_data_str=""
  if [[ $value_src_data_file != "" ]]; then
     value_src_data_str="--value_src_data_type=$value_src_data_type --value_src_data_file=$value_src_data_file"
  fi

  workload=${workloads[$run]}

  echo "Launching run instance:"$instance" node:"$node" memnode:"$memnode" nvme:"$nvme" workload:"$workload" ops:"$ops `date`

  if [[ $workload == "readrandom" ]]; then
    set -x
    numactl $numactl_cpu --membind=$memnode $rocksdb_folder/db_bench --benchmarks="readrandom,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --reads=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  elif [[ $workload == "readrandomwriterandom" ]]; then
    set -x
    numactl $numactl_cpu --membind=$memnode $rocksdb_folder/db_bench --benchmarks="readrandomwriterandom,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --reads=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  elif [[ $workload == "readwhilewriting" ]]; then
    set -x
    numactl $numactl_cpu --membind=$memnode $rocksdb_folder/db_bench --benchmarks="readwhilewriting,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --reads=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  elif [[ $workload == "overwrite" ]]; then
    set -x
    numactl $numactl_cpu --membind=$node $rocksdb_folder/db_bench --benchmarks="overwrite,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --writes=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  # For fillrandom, don't select --use_existing_db
  elif [[ $workload == "fillrandom" ]]; then
    set -x
    numactl $numactl_cpu --membind=$node $rocksdb_folder/db_bench --benchmarks="fillrandom,stats" $statistics_str --db=$db_instance \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --writes=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  # For fillseq, don't select --use_existing_db, $duration_str, writes
  elif [[ $workload == "fillseq" ]]; then
    set -x
    numactl $numactl_cpu --membind=$node $rocksdb_folder/db_bench --benchmarks="fillseq,stats" $statistics_str --db=$db_instance \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  fi
}


replace_output="";
function replace_instance_node() {
  local str=$1  # string to do replacement on
  local instance=$2
  local node=$3
  local nvme=$4

  replace_output=$str
  if [[ $str != "" ]]; then
    replace_output=${replace_output//%%%/$nvme}    # replace %% with nvme number
    replace_output=${replace_output//%%/$node}     # replace %% with node number
    replace_output=${replace_output//%/$instance}  # replace % with instance number
  fi
}


node_output=0
function calculate_node() {
  local instance=$1

  node_output=$((instance%numa_nodes))
}


memnode_output=0
function calculate_memnode() {
  local node=$1

  if [[ $use_kmem == "true" ]]; then
    # Assumes that kmem nodes align with cpu NUMA nodes
    memnode_output="$node,$((instance%numa_nodes+numa_nodes))"
  else
    memnode_output=$node
  fi
}


nvme_output=0
function calculate_nvme() {
  local instance=$1

  nvme_output=$((instance%nvme_drives))
}


function prefill_instances() {
  local data_prefix=$1
  local run=$2

  if [[ ${prefill[$run]} == "c" ]]; then
    cleanup
  elif [[ ${prefill[$run]} == "y" ]]; then
    cleanup
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      calculate_node $instance
      calculate_nvme $instance
      prefill_instance $instance $node_output $nvme_output $data_prefix $run
    done
  fi
}


function run_instances() {
  local data_prefix=$1
  local run=$2

  for (( instance=0; instance<$num_instances; instance++ ));
  do
    calculate_node $instance
    calculate_nvme $instance
    run_instance $instance $node_output $nvme_output $data_prefix $run
  done
}


function wait_dbbench() {
  local data_prefix=$1

  sleep 5
  echo "Waiting for run to complete " `date`

  local elapsed=0
  local collect_count=0
  local active_instances=1
  while [[ $active_instances -gt 0 ]]; do
    active_instances=$(ps -A | grep db_bench$ -c)
    elapsed=$((elapsed+1))
    sleep 1

    if [[ $elapsed -ge $collect_interval ]]; then
      collect_stats $data_prefix-$collect_count
      collect_count=$((collect_count+1))
      elapsed=0
    fi
  done
}


function generate_wait_script() {
  local timeout=$1

  cat << EOF > $base_data_folder/wait_dbbench.sh
  active_instances=1
  timeout=$timeout
  timeout_counter=0
  while [[ \$active_instances -gt 0 ]] && [[ \$timeout_counter -lt \$timeout ]]; do
    active_instances=\$(ps -A | grep db_bench\$ -c)
    timeout_counter=\$((timeout_counter+1))
    sleep 1
  done
EOF

  chmod +x $base_data_folder/wait_dbbench.sh
}


function collect_stats() {
  local data_prefix=$1

  if [[ $collect_memory == "y" ]]; then
    collect_memory_stats $data_prefix
  fi
  if [[ $collect_offcpu == "y" ]]; then
    collect_offcpu_stats $data_prefix
  fi
}


function collect_memory_stats() {
  local data_prefix=$1

  free > $data_folder/mem_${data_prefix}.txt
  df >> $data_folder/mem_${data_prefix}.txt
  numactl --hardware >> $data_folder/mem_${data_prefix}.txt
  cat /proc/meminfo >> $data_folder/mem_${data_prefix}.txt

  # For QAT only
  # Fix device addresses for specific system
  # Find the directories using ls /sys/kernel/debug/qat*
  # Reset the counters by restarting qat_service: service qat_service restart
  #echo QAT-1a >> $data_folder/mem_${data_prefix}.txt
  #cat /sys/kernel/debug/qat_c6xx_0000\:1a\:00.0/fw_counters >> $data_folder/mem_${data_prefix}.txt
  #echo QAT-1c >> $data_folder/mem_${data_prefix}.txt
  #cat /sys/kernel/debug/qat_c6xx_0000\:1c\:00.0/fw_counters >> $data_folder/mem_${data_prefix}.txt
  #echo QAT-1e >> $data_folder/mem_${data_prefix}.txt
  #cat /sys/kernel/debug/qat_c6xx_0000\:1e\:00.0/fw_counters >> $data_folder/mem_${data_prefix}.txt
  #echo QAT-b1 >> $data_folder/mem_${data_prefix}.txt
  #cat /sys/kernel/debug/qat_c6xx_0000\:b1\:00.0/fw_counters >> $data_folder/mem_${data_prefix}.txt
  #echo QAT-b3 >> $data_folder/mem_${data_prefix}.txt
  #cat /sys/kernel/debug/qat_c6xx_0000\:b3\:00.0/fw_counters >> $data_folder/mem_${data_prefix}.txt
  #echo QAT-b5 >> $data_folder/mem_${data_prefix}.txt
  #cat /sys/kernel/debug/qat_c6xx_0000\:b5\:00.0/fw_counters >> $data_folder/mem_${data_prefix}.txt
}


function collect_offcpu_stats() {
  local data_prefix=$1

  $bcc_folder/cpudist$bcc_suffix -O -P > $data_folder/offcpu_temp.txt &
  local pid=$!
  sleep 10
  kill -INT $pid
  sleep 2  # wait for process to get killed, otherwise output file will be empty
  cat $data_folder/offcpu_temp.txt | grep db_bench$ -A 21 > $data_folder/offcpu_${data_prefix}.txt
  rm -f $data_folder/offcpu_temp.txt
}


# Calculate total space used across all drives
function collect_drive_used_stats() {
  local data_prefix=$1

  drive_used=0
  for (( nvme=0; nvme<$nvme_drives; nvme++ ));
  do
    replace_instance_node $drive 0 0 $nvme
    one_drive_used=$(df $replace_output | grep nvme | tr -s ' ' | cut -d ' ' -f 3)
    if [[ -z $one_drive_used ]]; then
      one_drive_used=0
    fi
    drive_used=$(($drive_used+$one_drive_used))
  done
  echo "Drive space used: "$drive_used >> $data_folder/mem_${data_prefix}.txt
}


# Calculate total space used by DB directories
function collect_db_size_stats() {
  local data_prefix=$1

  dbs_size=0
  for (( instance=0; instance<$num_instances; instance++ ));
  do
    db_size=$(du -s ${db_instances[$instance]} | cut -f 1)
    dbs_size=$(($dbs_size+$db_size))
  done
  echo "DB size: "$dbs_size >> $data_folder/mem_${data_prefix}.txt
}


function collect_cpu_util() {

  sleep $cpu_util_delay
  echo "CPU utilization - collection start " `date`
  sar $cpu_util_duration 1 > $data_folder/cpu_util_sar.txt
  cpu_usr=$(cat $data_folder/cpu_util_sar.txt | grep Average | tr -s ' ' | cut -d ' ' -f 3)
  cpu_sys=$(cat $data_folder/cpu_util_sar.txt | grep Average | tr -s ' ' | cut -d ' ' -f 5)
  cpu_tot=$(echo "$cpu_usr+$cpu_sys" | bc)
  echo $cpu_tot > $data_folder/cpu_util.txt

  echo "CPU utilization - collection end " `date`
}


tpts=()  # to store throughputs needed for emon post-processing script
function aggregate_stats() {
  local data_prefix=$1
  local run=$2

  tpts[$run]=0

  echo "Aggregate stats"

    if [[ $perf_stat == "y" ]]; then
      echo "process perf report" `date`
      perf report -fn  -s symbol -i $data_folder/perf/perf_syswide.dat > $data_folder/perf/perf_syswide.out
    fi

    if [[ $memcomp_pmu == "y" ]]; then
      echo "process memcomp_pmu report" `date`
      cd $data_folder/memcomp_pmu
      python3.8 $memcomp_dir/iax-pmu-plot.py
      cd $src
    fi

  if [[ $summary_ops == true ]]; then
    echo "OPS" > $data_folder/aggr_${data_prefix}.txt
    total_ops=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "ops/sec " | cut -d ':' -f 2 | cut -d 'p' -f 2 | tr -d ' ' | tr -d 'o')
      total_ops=$((total_ops+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total ops: "$total_ops"\n" >> $data_folder/aggr_${data_prefix}.txt
    tpts[$run]=$total_ops
  fi

  # When extra stats are enabled, summarize one of the last intervals for all threads
  # Summarize 10 intervals before end. The very last one may be affected by instances not finishing at the same time
  if [[ $summary_interval_ops == true && $stats_interval_seconds -gt 0 ]]; then
    echo "INTERVAL OPS" >> $data_folder/aggr_${data_prefix}.txt
    total_interval_ops=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst_interval_ops=0
      for (( thread=0; thread<${threads[$run]}; thread++ ));
      do
        inst=$(grep 'thread '$thread $data_folder/run_stats_${data_prefix}_$instance.txt | tail -10 | head -1 | cut -d '(' -f 3 | cut -d '.' -f 1)
        total_interval_ops=$((total_interval_ops+inst))
        inst_interval_ops=$((inst_interval_ops+inst))
      done
    echo "Instance: "$instance" val: "$inst_interval_ops >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total interval_ops: "$total_interval_ops"\n" >> $data_folder/aggr_${data_prefix}.txt
    tpts[$run]=$total_interval_ops
  fi

  if [[ $summary_block_cache_misses == true ]]; then
    echo "BLOCK CACHE MISSES" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_misses=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_misses=$((total_bc_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_misses: "$total_bc_misses"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_hits == true ]]; then
    echo "BLOCK CACHE HITS" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_hits=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_hits=$((total_bc_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_hits: "$total_bc_hits"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_misses == true && $summary_block_cache_hits == true ]]; then
    if [[ $total_bc_hits -gt 0 ]]; then
      echo -e "Block Cache Hit Rate: "$((total_bc_hits*100/(total_bc_misses+total_bc_hits)))"\n" >> $data_folder/aggr_${data_prefix}.txt
    else
      echo -e "Block Cache Hit Rate: N/A\n" >> $data_folder/aggr_${data_prefix}.txt
    fi
  fi


  if [[ $summary_block_cache_data_misses == true ]]; then
    echo "BLOCK CACHE DATA MISSES" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_data_misses=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.data.miss" | cut -d ':'   -f 2  | tr -d ' ')
      total_bc_data_misses=$((total_bc_data_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_data_misses: "$total_bc_data_misses"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_data_hits == true ]]; then
    echo "BLOCK CACHE DATA HITS" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_data_hits=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.data.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_data_hits=$((total_bc_data_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_data_hits: "$total_bc_data_hits"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_data_misses == true && $summary_block_cache_data_hits == true ]]; then
    if [[ $total_bc_data_hits -gt 0 ]]; then
      echo -e "Block Cache Data Hit Rate: "$((total_bc_data_hits*100/(total_bc_data_misses+total_bc_data_hits)))"\n" >> $data_folder/aggr_${data_prefix}.txt
    else
      echo -e "Block Cache Data Hit Rate: N/A\n" >> $data_folder/aggr_${data_prefix}.txt
    fi
  fi


  if [[ $summary_block_cache_filter_misses == true ]]; then
    echo "BLOCK CACHE FILTER MISSES" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_filter_misses=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.filter.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_filter_misses=$((total_bc_filter_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_filter_misses: "$total_bc_filter_misses"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_filter_hits == true ]]; then
    echo "BLOCK CACHE FILTER HITS" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_filter_hits=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.filter.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_filter_hits=$((total_bc_filter_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_filter_hits: "$total_bc_filter_hits"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_filter_misses == true && $summary_block_cache_filter_hits == true ]]; then
    if [[ $total_bc_filter_hits -gt 0 ]]; then
      echo -e "Block Cache Filter Hit Rate: "$((total_bc_filter_hits*100/(total_bc_filter_misses+total_bc_filter_hits)))"\n" >> $data_folder/aggr_${data_prefix}.txt
    else
      echo -e "Block Cache Filter Hit Rate: N/A\n" >> $data_folder/aggr_${data_prefix}.txt
    fi
  fi


  if [[ $summary_block_cache_index_misses == true ]]; then
    echo "BLOCK CACHE INDEX MISSES" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_index_misses=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.index.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_index_misses=$((total_bc_index_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_index_misses: "$total_bc_index_misses"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_index_hits == true ]]; then
    echo "BLOCK CACHE INDEX HITS" >> $data_folder/aggr_${data_prefix}.txt
    total_bc_index_hits=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.index.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_index_hits=$((total_bc_index_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total block_cache_index_hits: "$total_bc_index_hits"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_block_cache_index_misses == true && $summary_block_cache_index_hits == true ]]; then
    if [[ $total_bc_index_hits -gt 0 ]]; then
      echo -e "Block Cache Index Hit Rate: "$((total_bc_index_hits*100/(total_bc_index_misses+total_bc_index_hits)))"\n" >> $data_folder/aggr_${data_prefix}.txt
    else
      echo -e "Block Cache Index Hit Rate: N/A\n" >> $data_folder/aggr_${data_prefix}.txt
    fi
  fi


  if [[ $summary_compressed_block_cache_misses == true ]]; then
    echo "COMPRESSED BLOCK CACHE MISSES" >> $data_folder/aggr_${data_prefix}.txt
    total_cbc_misses=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cachecompressed.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_cbc_misses=$((total_cbc_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total compressed_block_cache_misses: "$total_cbc_misses"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_compressed_block_cache_hits == true ]]; then
    echo "COMPRESSED BLOCK CACHE HITS" >> $data_folder/aggr_${data_prefix}.txt
    total_cbc_hits=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cachecompressed.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_cbc_hits=$((total_cbc_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total compressed_block_cache_hits: "$total_cbc_hits"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_compressed_block_cache_misses == true && $summary_compressed_block_cache_hits == true ]]; then
    if [[ $total_cbc_hits -gt 0 ]]; then
      echo -e "Compressed Block Cache Hit Rate: "$((total_cbc_hits*100/(total_cbc_misses+total_cbc_hits)))"\n" >> $data_folder/aggr_${data_prefix}.txt
    else
      echo -e "Compressed Block Cache Hit Rate: N/A\n" >> $data_folder/aggr_${data_prefix}.txt
    fi
  fi


  if [[ $summary_p50_get_latency == true ]]; then
    echo "P50 GET LATENCY" >> $data_folder/aggr_${data_prefix}.txt
    total_p50_get_latency=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.get.micros" | cut -d ' ' -f 4)
      total_p50_get_latency=$(echo "scale=2; $total_p50_get_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    avg_p50_get_latency=$(echo "scale=2; $total_p50_get_latency/$num_instances" | bc)
    echo -e "Avg p50_get_latency: "$avg_p50_get_latency"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_p99_get_latency == true ]]; then
    echo "P99 GET LATENCY" >> $data_folder/aggr_${data_prefix}.txt
    total_p99_get_latency=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.get.micros" | cut -d ' ' -f 10)
      total_p99_get_latency=$(echo "scale=2; $total_p99_get_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    avg_p99_get_latency=$(echo "scale=2; $total_p99_get_latency/$num_instances" | bc)
    echo -e "Avg p99_get_latency: "$avg_p99_get_latency"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi


  if [[ $summary_p50_put_latency == true ]]; then
    echo "P50 PUT LATENCY" >> $data_folder/aggr_${data_prefix}.txt
    total_p50_put_latency=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.write.micros" | cut -d ' ' -f 4)
      total_p50_put_latency=$(echo "scale=2; $total_p50_put_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    avg_p50_put_latency=$(echo "scale=2; $total_p50_put_latency/$num_instances" | bc)
    echo -e "Avg p50_put_latency: "$avg_p50_put_latency"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_p99_put_latency == true ]]; then
    echo "P99 PUT LATENCY" >> $data_folder/aggr_${data_prefix}.txt
    total_p99_put_latency=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.write.micros" | cut -d ' ' -f 10)
      total_p99_put_latency=$(echo "scale=2; $total_p99_put_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    avg_p99_put_latency=$(echo "scale=2; $total_p99_put_latency/$num_instances" | bc)
    echo -e "Avg p99_put_latency: "$avg_p99_put_latency"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi


  if [[ $summary_p50_compression_nanos == true ]]; then
    echo "P50 COMPRESSION NANOS" >> $data_folder/aggr_${data_prefix}.txt
    total_p50_compression_nanos=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.compression.times.nanos" | cut -d ' ' -f 4)
      total_p50_compression_nanos=$(echo "scale=2; $total_p50_compression_nanos+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    avg_p50_compression_nanos=$(echo "scale=2; $total_p50_compression_nanos/$num_instances" | bc)
    echo -e "Avg p50_compression_nanos: "$avg_p50_compression_nanos"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi

  if [[ $summary_p50_decompression_nanos == true ]]; then
    echo "P50 DECOMPRESSION NANOS" >> $data_folder/aggr_${data_prefix}.txt
    total_p50_decompression_nanos=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.decompression.times.nanos" | cut -d ' ' -f 4)
      total_p50_decompression_nanos=$(echo "scale=2; $total_p50_decompression_nanos+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    avg_p50_decompression_nanos=$(echo "scale=2; $total_p50_decompression_nanos/$num_instances" | bc)
    echo -e "Avg p50_decompression_nanos: "$avg_p50_decompression_nanos"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi


  if [[ $summary_stall_micros == true ]]; then
    echo "STALL MICROS" >> $data_folder/aggr_${data_prefix}.txt
    total_stall_micros=0
    for (( instance=0; instance<$num_instances; instance++ ));
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.stall.micros" | cut -d ':' -f 2  | tr -d ' ')
      total_stall_micros=$((total_stall_micros+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/aggr_${data_prefix}.txt
    done
    echo -e "Total total_stall_micros: "$total_stall_micros"\n" >> $data_folder/aggr_${data_prefix}.txt
  fi


  echo "DRIVE SPACE USED" >> $data_folder/aggr_${data_prefix}.txt
  drive_used_start=$(grep "Drive space used" $data_folder/mem_start.txt | cut -d ':' -f 2)
  drive_used_end=$(grep "Drive space used" $data_folder/mem_end.txt | cut -d ':' -f 2)
  echo "Drive space start: "$drive_used_start >> $data_folder/aggr_${data_prefix}.txt
  echo "Drive space end:   "$drive_used_end >> $data_folder/aggr_${data_prefix}.txt
  echo "Drive space delta: "$(($drive_used_end-$drive_used_start)) >> $data_folder/aggr_${data_prefix}.txt

  echo "" >> $data_folder/aggr_${data_prefix}.txt
  echo "DB SIZE" >> $data_folder/aggr_${data_prefix}.txt
  db_size=$(grep "DB size" $data_folder/mem_end.txt | cut -d ':' -f 2)
  echo "DB size: " $db_size >> $data_folder/aggr_${data_prefix}.txt
}


data_folder=""
function create_data_folders() {
  local run=$1

  echo "Creating data folders"
  data_folder=$base_data_folder"/data_"${run_names[$run]}
  mkdir -p $data_folder
  if [[ $emon == "y" ]]; then
    mkdir $data_folder/emon
  fi
  if [[ $sep == "y" ]]; then
    mkdir $data_folder/sep
  fi
  if [[ $flame_graph == "y" ]]; then
    mkdir $data_folder/flame
  fi
  if [[ $flame_graph_offcpu == "y" ]]; then
    mkdir $data_folder/flame_offcpu
  fi
  if [[ $perf_stat == "y" ]]; then
    mkdir $data_folder/perf
  fi
  if [[ $memcomp_pmu == "y" ]]; then
    mkdir $data_folder/memcomp_pmu
  fi
  if [[ $collect_config == "y" ]]; then
    mkdir $data_folder/config
  fi
}


function generate_emon_script() {

  cat << EOF > $base_data_folder/emon_post_processing.ps1
# process.cmd should have this line for throughput
# set TPS=--tps _TPT_

EOF

  echo -n '$runs=@(' >> $base_data_folder/emon_post_processing.ps1
  for (( i=0; i<$num_runs; i++ ));
  do
    echo -n \"data_${run_names[$i]}\" >> $base_data_folder/emon_post_processing.ps1
    if [[ $i -lt $(($num_runs-1)) ]]; then
      echo -n "," >> $base_data_folder/emon_post_processing.ps1
    fi
  done
  echo ')' >> $base_data_folder/emon_post_processing.ps1

  echo -n '$tpts=' >> $base_data_folder/emon_post_processing.ps1
  for (( i=0; i<$num_runs; i++ ));
  do
    echo -n ${tpts[$i]} >> $base_data_folder/emon_post_processing.ps1
    if [[ $i -lt $(($num_runs-1)) ]]; then
      echo -n "," >> $base_data_folder/emon_post_processing.ps1
    fi
  done
  echo "" >> $base_data_folder/emon_post_processing.ps1

  echo '$sub_folder="emon"' >> $base_data_folder/emon_post_processing.ps1
  echo '$edp_folder="'$edp_folder"\"" >> $base_data_folder/emon_post_processing.ps1
  echo "" >> $base_data_folder/emon_post_processing.ps1

  cat << "EOF" >> $base_data_folder/emon_post_processing.ps1
For($i=0; $i -lt $runs.length; $i++) {
  $data_folder=$runs[$i] + "\" + $sub_folder
  $tpt=$tpts[$i]

  "Processing " + $runs[$i]

  cp $data_folder\emon.dat $edp_folder
  cp $data_folder\emon-v.dat $edp_folder
  cp $data_folder\emon-m.dat $edp_folder

  Push-Location $edp_folder
  (Get-Content process.cmd).replace('_TPT_', $tpt) | Set-Content process.cmd
  cmd.exe /c ".\process.cmd"
  (Get-Content process.cmd).replace('set TPS=--tps ' + $tpt, 'set TPS=--tps _TPT_') | Set-Content process.cmd
  Pop-Location

  $output_file=$data_folder + "\summary_" + $runs[$i] + ".xlsx"
  cp $edp_folder\summary.xlsx $output_file

  # Cleanup
  rm $edp_folder\emon.dat
  rm $edp_folder\emon-v.dat
  rm $edp_folder\emon-m.dat
  rm $edp_folder\summary.xlsx
}
EOF

}


function prep_collection() {
  local data_prefix=$1
  local run=$2

  prefill_instances $data_prefix $run
  wait_dbbench $data_prefix"-prefill"
  collect_stats $data_prefix"-postprefill"
  run_instances $data_prefix $run
}


function collect_emon() {
  local run=$1

  echo "Run with EMON"
  if [[ $restart_for_each_collection == "y" ]]; then   # restart for each data collection
    prep_collection "emon" $run
  fi
  sleep $emon_delay

  if [[ $emon_arch == "intel" ]]; then
    source $emon_folder/sep_vars.sh > /dev/null
    if [[ $emon_driverless == "n" ]]; then
      $emon_folder/sepdk/src/insmod-sep --no-udev > /dev/null
      emon -v > $data_folder/emon/emon-v.dat
      emon -M > $data_folder/emon/emon-m.dat
      emon -i $emon_file > $data_folder/emon/emon.dat &
    else
      emon -i $emon_file --driverless > $data_folder/emon/emon.dat &
    fi

    sleep $emon_duration  # data collection duration
    emon -stop

    #$emon_folder/sepdk/src/rmmod-sep > /dev/null
    #unset_emon_variables
  elif [[ $emon_arch == "arm" ]]; then
    $emon_arm_folder/collect-arm-perf 200 $emon_duration $data_folder/emon/perf-output.txt
  fi

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "emon-run"
  fi
}


function collect_sep() {
  local run=$1

  echo "Run with SEP"
  # Assumes that the run is longer than 150 s
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "sep" $run
  fi
  sleep $sep_delay

  source $emon_folder/sep_vars.sh > /dev/null
  $emon_folder/sepdk/src/insmod-sep > /dev/null
  sep -start -d $sep_duration -out $data_folder/sep/sep_data &> /dev/null

  $emon_folder/sepdk/src/rmmod-sep > /dev/null
  unset_emon_variables

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "sep-run"
  fi
}


function unset_emon_variables() {
  # Unset variables exported by sep_vars.sh. These prevent VTune collection from running.
  unset SEP_LOC_PATH
  unset MTOOL_PATH
  unset ANDROID_TARGET_PATH
  unset PERL5LIB
  unset EMON_API_HEADER_PATH
  unset SEP_INSTALL_PATH
  unset SEP_LIB_INSTALL_PATH
  unset INTEL_LIBITTNOTIFY64
}


function collect_pat() {
  local run=$1

  echo "Run with PAT"
  generate_wait_script $pat_duration
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "pat" $run
  fi
  sleep $pat_delay

  cd $app_folder/PAT/PAT-collecting-data
  ./pat run data

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "pat-run"
  fi

  yes | cp -r $app_folder/PAT/PAT-collecting-data/results/data $data_folder/pat
  cd $rocksdb_folder
}


function collect_flame_graph() {
  local run=$1

  echo "Run with Flame Graph"
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "flame" $run
  fi
  sleep $flame_delay

  perf record -F 99 -a -g --call-graph dwarf -o $data_folder/flame/perf.data -- sleep $flame_duration

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "flame-run"
  fi
}


function collect_flame_graph_offcpu() {
  local run=$1

  echo "Run with Flame Graph off-cpu"
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "flame-offcpu" $run
  fi
  sleep $flame_delay

  $bcc_folder/offcputime$bcc_suffix -df -p `pgrep -nx db_bench` $flame_duration > $data_folder/flame_offcpu/offcpu.stacks

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "flame-offcpu-run"
  fi
}


function collect_vtune() {
  local run=$1

  pkill -x vtune

  echo "Run with VTune"
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "vtune" $run
  fi
  sleep $vtune_delay

  source $vtune_folder/vtune-vars.sh > /dev/null
  $vtune_folder/sepdk/src/insmod-sep > /dev/null
  pid=$(pgrep db_bench -n)

  # threading analysis
  # stack-size=1024 is too limited and makes spin/wait time accounting incorrect
  vtune -collect threading -knob sampling-and-waits=hw -knob stack-size=0 \
  -target-pid=$pid -result-dir $data_folder/vtune_threading -duration=$vtune_duration -data-limit=20000 -finalization-mode=none

  sleep $vtune_delay

  # uarch analysis
  vtune -collect uarch-exploration \
  -target-pid=$pid -result-dir $data_folder/vtune_uarch -duration=$vtune_duration -data-limit=20000 -finalization-mode=none

  sleep $vtune_delay

  # memory access analysis
  vtune -collect memory-access -knob dram-bandwidth-limits=false \
  -target-pid=$pid -result-dir $data_folder/vtune_memory -duration=$vtune_duration -data-limit=20000 -finalization-mode=none

  # Custom hardware event-based sampling (customized from threading)
  #vtune -collect-with runsa -target-pid=$pid -result-dir $data_folder/vtune -duration=$vtune_duration -data-limit=10000 -finalization-mode=none \
  #-knob sampling-interval=10 \
  #-knob stack-size=8192 -knob stack-type=software -knob enable-stack-collection=true \
  #-knob enable-context-switches=true -knob collect-io-waits=true -knob io-mode=stack \
  #-knob event-config=CPU_CLK_UNHALTED.THREAD:sa=2400000,CPU_CLK_UNHALTED.REF_TSC:sample:sa=2400000,INST_RETIRED.ANY:sample:sa=2400000,CPU_CLK_UNHALTED.REF_XCLK:sa=100003,CPU_CLK_UNHALTED.ONE_THREAD_ACTIVE:sa=100003,UOPS_RETIRED.RETIRE_SLOTS:sample:sa=2000003

  # Custom user-space sampling (customized from threading)
  #vtune -collect-with runss -target-pid=$pid -result-dir $data_folder/vtune -duration=$vtune_duration -data-limit=10000 -finalization-mode=none \
  #-knob cpu-samples-mode=stack -knob waits-mode=stack -knob signals-mode=stack -knob io-mode=stack -knob enable-user-sync=true \
  #-knob enable-context-switches=true -knob collect-io-waits=true -knob io-mode=stack

  $vtune_folder/sepdk/src/rmmod-sep > /dev/null

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "vtune-run"
  fi
}


function collect_perf_stat() {
  local run=$1

  echo "Run perf stat"
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "perf-stat" $run
  fi
  sleep $perf_stat_delay

  echo "starting perf collection" `date`
  perf record -a -o $data_folder/perf/perf_syswide.dat -- sleep $perf_stat_duration2
  perf stat -a $perf_stat_options -o $data_folder/perf/perf_stat.txt -- sleep $perf_stat_duration1
  echo "end perf collection" `date`

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "perf-stat-run"
  fi
}

function collect_memcomp_pmu() {
  local run=$1

  echo "Run memcomp_pmu"
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "memcomp-pmu" $run
  fi
  sleep $memcomp_pmu_delay

  echo "starting memcomp_pmu collection" `date`
  cd $data_folder/memcomp_pmu
  python3.8 $memcomp_dir/memcomp-pmu.py &
  sleep $memcomp_pmu_duration
  kill "$!"
  echo "end memcomp_pmu collection" `date`
  cd $src

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "memcomp-pmu-run"
  fi
}

function collect_custom_data() {
  local run=$1

  echo "Run custom data"
  if [[ $restart_for_each_collection == "y" ]]; then
    prep_collection "custom-data" $run
  fi
  sleep $custom_data_delay

  eval $custom_data_command

  if [[ $restart_for_each_collection == "y" ]]; then
    collect_cpu_util
    wait_dbbench "custom-data-run"
  fi
}


function collect_alone() {
  local run=$1

  echo "Run alone"
  prep_collection "alone" $run

  wait_dbbench "alone-run"
}




# Kill existing instances
pkill -x db_bench
wait_dbbench

eval $init_command

num_runs=${#run_names[@]}
for (( i=0; i<$num_runs; i++ ));
do
  echo "Run "$i" started"

  create_data_folders $i

  if [[ $post_process_only == "n" ]]; then
    if [[ ${prefill[$i]} == "c" || ${prefill[$i]} == "y" ]]; then
      cleanup
    fi

    collect_stats "start"
    collect_drive_used_stats "start"

    if [[ $restart_for_each_collection != "y" ]]; then   # start once for all the data collections
      prep_collection "all" $i
    fi

    if [[ -z $start_command_output_file ]]; then
      eval $start_command
    else
      eval $start_command > $data_folder/$start_command_output_file
    fi

    # Collect data
    if [[ $emon == "y" ]]; then
      collect_emon $i
      echo -e "\n"
    fi

    if [[ $sep == "y" ]]; then
      collect_sep $i
      echo -e "\n"
    fi

    if [[ $pat == "y" ]]; then
      collect_pat $i
      echo -e "\n"
    fi

    if [[ $flame_graph == "y" ]]; then
      collect_flame_graph $i
      echo -e "\n"
    fi

    if [[ $flame_graph_offcpu == "y" ]]; then
      collect_flame_graph_offcpu $i
      echo -e "\n"
    fi

    if [[ $vtune == "y" ]]; then
      collect_vtune $i
      echo -e "\n"
    fi

    if [[ $perf_stat == "y" ]]; then
      collect_perf_stat $i
      echo -e "\n"
    fi

    if [[ $memcomp_pmu == "y" ]]; then
      collect_memcomp_pmu $i
      echo -e "\n"
    fi

    if [[ $custom_data == "y" ]]; then
      collect_custom_data $i
      echo -e "\n"
    fi

    if [[ $alone == "y" ]]; then
      collect_alone $i
      echo -e "\n"
    fi

    if [[ $restart_for_each_collection != "y" ]]; then
      collect_cpu_util
      wait_dbbench "all-run"
    fi

    if [[ -z $end_command_output_file ]]; then
      eval $end_command
    else
      eval $end_command > $data_folder/$end_command_output_file
    fi

    collect_stats "end"
    collect_drive_used_stats "end"
    collect_db_size_stats "end"
  fi


  # Post-process
  echo -e "Post-processing..."

  if [[ $restart_for_each_collection == "y" ]]; then
    if [[ $emon == "y" ]]; then
      aggregate_stats "emon" $i
    fi

    if [[ $sep == "y" ]]; then
      aggregate_stats "sep" $i
    fi

    if [[ $pat == "y" ]]; then
      aggregate_stats "pat" $i
    fi

    if [[ $flame_graph == "y" ]]; then
      aggregate_stats "flame" $i
    fi

    if [[ $flame_graph_offcpu == "y" ]]; then
      aggregate_stats "flame-offcpu" $i
    fi

    if [[ $vtune == "y" ]]; then
      aggregate_stats "vtune" $i
    fi

    if [[ $perf_stat == "y" ]]; then
      echo "process perf report" `date`
      perf report -fn  -s symbol -i $data_folder/perf/perf_syswide.dat > $data_folder/perf/perf_syswide.out
      aggregate_stats "perf-stat" $i
    fi

    if [[ $memcomp_pmu == "y" ]]; then
      echo "process memcomp_pmu report" `date`
      cd $data_folder/memcomp_pmu
      python3.8 $memcomp_dir/iax-pmu-plot.py
      cd $src
    fi


    if [[ $alone == "y" ]]; then
      aggregate_stats "alone" $i
    fi
  else
    aggregate_stats "all" $i
  fi

  if [[ $emon == "y" && $emon_arch == "arm" ]]; then
    $emon_arm_folder/armEMONOutput.py -i $data_folder/emon/perf-output.txt -o $data_folder/emon/arm-emon.dat
  fi

  if [[ $flame_graph == "y" ]]; then
    echo "Generating flame graph"
    cd $data_folder/flame
    perf script > out.perf
    $app_folder/FlameGraph/stackcollapse-perf.pl out.perf > out.folded
    $app_folder/FlameGraph/flamegraph.pl out.folded > graph.svg
    rm -f perf.data  # large file
    if [[ $flame_graph_flamescope_data == "n" ]]; then
      rm -f out.perf   # large file. Needed for FlameScope
    fi
    cd $rocksdb_folder
  fi

  if [[ $flame_graph_offcpu == "y" ]]; then
    echo "Generating flame graph off-cpu"
    cd $data_folder/flame_offcpu
    $app_folder/FlameGraph/flamegraph.pl --color=io --title="Off-CPU Time Flame Graph" --countname=us < offcpu.stacks > offcpu.svg
    cd $rocksdb_folder
  fi

  if [[ $vtune == "y" ]]; then
    vtune -finalize -result-dir $data_folder/vtune_threading -finalization-mode=full -discard-raw-data
    vtune -finalize -result-dir $data_folder/vtune_uarch -finalization-mode=full -discard-raw-data
    vtune -finalize -result-dir $data_folder/vtune_memory -finalization-mode=full -discard-raw-data
  fi

  echo "Run "$i" completed"
done

if [[ $emon == "y" ]]; then
  generate_emon_script
fi


# Paired run summaries
paired_summary_file=$base_data_folder"/paired_summary.txt"
echo "" | tee $paired_summary_file
num_paired_runs=${#paired_run_names[@]}
for (( i=0; i<$num_paired_runs; i++ ));
do
  baseline_run=${baseline_runs[$i]}
  baseline_fill_run=${baseline_fill_runs[$i]}
  target_run=${target_runs[$i]}
  target_fill_run=${target_fill_runs[$i]}

  echo "" | tee -a $paired_summary_file
  echo "" | tee -a $paired_summary_file
  echo "Test: "${paired_run_names[$i]}  | tee -a $paired_summary_file
  echo "" | tee -a $paired_summary_file

  # BASELINE
  baseline_data_folder=$base_data_folder"/data_"${run_names[$baseline_run]}
  aggr_file=$baseline_data_folder/aggr_all.txt
  baseline_ops=$(grep "Total ops" $aggr_file | tr -s ' ' | cut -d ' ' -f 3)
  baseline_p99get=$(grep "Avg p99_get_latency" $aggr_file | tr -s ' ' | cut -d ' ' -f 3)
  baseline_cpu_util=$(cat $baseline_data_folder/cpu_util.txt)

  baseline_data_folder=$base_data_folder"/data_"${run_names[$baseline_fill_run]}
  aggr_file=$baseline_data_folder/aggr_all.txt
  baseline_data_size=$(grep "DB size" $aggr_file | tr -s ' ' | cut -d ' ' -f 3)

  echo "Baseline: "${baseline_run_names[$i]} | tee -a $paired_summary_file
  echo "Throughput (ops/s): "$baseline_ops | tee -a $paired_summary_file
  echo "p99 get latency (us): "$baseline_p99get | tee -a $paired_summary_file
  echo "Data size (kB): "$baseline_data_size | tee -a $paired_summary_file
  echo "CPU util (%): "$baseline_cpu_util | tee -a $paired_summary_file
  echo "" | tee -a $paired_summary_file

  #TARGET
  target_data_folder=$base_data_folder"/data_"${run_names[$target_run]}
  aggr_file=$target_data_folder/aggr_all.txt
  target_ops=$(grep "Total ops" $aggr_file | tr -s ' ' | cut -d ' ' -f 3)
  target_p99get=$(grep "Avg p99_get_latency" $aggr_file | tr -s ' ' | cut -d ' ' -f 3)
  target_cpu_util=$(cat $target_data_folder/cpu_util.txt)

  target_data_folder=$base_data_folder"/data_"${run_names[$target_fill_run]}
  aggr_file=$target_data_folder/aggr_all.txt
  target_data_size=$(grep "DB size" $aggr_file | tr -s ' ' | cut -d ' ' -f 3)

  echo "Target: "${target_run_names[$i]} | tee -a $paired_summary_file
  echo "Throughput (ops/s): "$target_ops | tee -a $paired_summary_file
  echo "p99 get latency (us): "$target_p99get | tee -a $paired_summary_file
  echo "Data size (kB): "$target_data_size | tee -a $paired_summary_file
  echo "CPU util (%): "$target_cpu_util | tee -a $paired_summary_file
  echo "" | tee -a $paired_summary_file

  # CHANGE
  pcdelta_ops=$(echo "scale=2; ($target_ops-$baseline_ops)*100/$baseline_ops" | bc)
  pcdelta_p99get=$(echo "scale=2; ($target_p99get-$baseline_p99get)*100/$baseline_p99get" | bc)
  pcdelta_data_size=$(echo "scale=2; ($target_data_size-$baseline_data_size)*100/$baseline_data_size" | bc)
  delta_cpu_util=$(echo "scale=2; ($target_cpu_util-$baseline_cpu_util)" | bc)

  echo "Change (target vs baseline)" | tee -a $paired_summary_file
  echo "Throughput (rel %): "$pcdelta_ops | tee -a $paired_summary_file
  echo "p99 get latency (rel %): "$pcdelta_p99get | tee -a $paired_summary_file
  echo "Data size (rel %): "$pcdelta_data_size | tee -a $paired_summary_file
  echo "CPU util (%): "$delta_cpu_util | tee -a $paired_summary_file
done

eval $final_command