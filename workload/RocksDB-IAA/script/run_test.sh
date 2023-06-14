#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# config IAA device
/rocksdb/scripts/configure_iaa_user 0 1,7

export  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib

mkdir -p /rocksdb_data/db_data

fill_cmd="${NUMA_OPTIONS} /rocksdb/rocksdb/db_bench --benchmarks=fillseq,stats --statistics --value_src_data_type=file_direct \
--value_src_data_file=/rocksdb/standard_calgary_corpus --db=/rocksdb_data/db_data --key_size=${KEY_SIZE} --value_size=${VALUE_SIZE} --block_size=${BLOCK_SIZE} \
--num=50000000 --bloom_bits=10 --compression_type=com.intel.iaa_compressor_rocksdb --compressor_options=execution_path=sw --histogram=1 --threads=8 --disable_wal=true"

readrandom_cmd="${NUMA_OPTIONS} /rocksdb/rocksdb/db_bench --benchmarks=readrandom,stats --statistics --value_src_data_type=file_direct \
--value_src_data_file=/rocksdb/standard_calgary_corpus --disable_auto_compactions=1 --use_existing_db=1 --db=/rocksdb_data/db_data --key_size=${KEY_SIZE} --value_size=${VALUE_SIZE} \
--compression_type=com.intel.iaa_compressor_rocksdb --compressor_options=execution_path=hw --num=50000000 --duration=50 --reads=10000000 --threads=${THREADS_NUM} --block_size=${BLOCK_SIZE} \
--memtablerep=skip_list --cache_size=-1 --bloom_bits=10 --use_direct_reads=0 --use_direct_io_for_flush_and_compaction=0 --verify_checksum=1 --stats_per_interval=1 \
--row_cache_size=0 --compressed_cache_size=-1 --use_cache_memkind_kmem_allocator=false --cache_index_and_filter_blocks=false \
--cache_numshardbits=6 --stats_interval_seconds=60 --histogram=1"

readrandomwriterandom_cmd="${NUMA_OPTIONS} /rocksdb/rocksdb/db_bench  --benchmarks=readrandomwriterandom,stats --statistics --value_src_data_type=file_direct \
--value_src_data_file=/rocksdb/standard_calgary_corpus --disable_auto_compactions=1 --use_existing_db=1 --db=/rocksdb_data/db_data --key_size=${KEY_SIZE} --value_size=${VALUE_SIZE} \
--compression_type=com.intel.iaa_compressor_rocksdb --compressor_options=execution_path=hw --readwritepercent=80 --num=50000000 --duration=50 --threads=${THREADS_NUM} \
--max_write_buffer_number=40 --write_buffer_size=1073741824 --block_size=4096 --max_background_jobs=2 --subcompactions=1 --memtablerep=skip_list --cache_size=-1 \
--cache_numshardbits=6 --bloom_bits=10 --use_direct_reads=0 --use_direct_io_for_flush_and_compaction=0 --verify_checksum=1 --stats_per_interval=1 \
--stats_interval_seconds=60 --histogram=1"

zstd_fill="${NUMA_OPTIONS} /rocksdb/rocksdb/db_bench --benchmarks=fillseq,stats --statistics --value_src_data_type=file_direct \
--value_src_data_file=/rocksdb/standard_calgary_corpus --db=/rocksdb_data/db_data --key_size=${KEY_SIZE} --value_size=${VALUE_SIZE} --block_size=${BLOCK_SIZE} \
--num=50000000 --bloom_bits=10 --compression_type=zstd --histogram=1 --threads=8 --disable_wal=true"

zstd_readrandom="${NUMA_OPTIONS} /rocksdb/rocksdb/db_bench --benchmarks=readrandom,stats --statistics --value_src_data_type=file_direct \
--value_src_data_file=/rocksdb/standard_calgary_corpus --db=/rocksdb_data/db_data --disable_auto_compactions=1 --use_existing_db=1 --key_size=${KEY_SIZE} \
--value_size=${VALUE_SIZE} --compression_type=zstd --num=50000000 --duration=50 --reads=10000000 --threads=8 --block_size=${BLOCK_SIZE} --memtablerep=skip_list \
--cache_size=-1 --bloom_bits=10 --use_direct_reads=0 --use_direct_io_for_flush_and_compaction=0 --verify_checksum=1 --stats_per_interval=1 --row_cache_size=0 \
--compressed_cache_size=-1 --use_cache_memkind_kmem_allocator=false --cache_index_and_filter_blocks=false --cache_numshardbits=6 --stats_interval_seconds=60 --histogram=1"

if [[ $TYPE == "fillseq" ]]; then
    set -x
    $fill_cmd > /dev/null 2>&1
    set +x
elif [[ $TYPE == "readrandom" ]]; then
    # randread
    set -x
    $fill_cmd > /dev/null 2>&1
    $readrandom_cmd
    set +x
elif [[ $TYPE == "readrandomwriterandom" ]]; then
    set -x
    $fill_cmd > /dev/null 2>&1
    $readrandomwriterandom_cmd
    set +x
elif [[ $TYPE == "zstd_readrandom" ]]; then
    set -x
    $zstd_fill > /dev/null 2>&1
    $zstd_readrandom
    set +x
fi