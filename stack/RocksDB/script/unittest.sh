#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# config IAA device

export  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
/iaa_config.sh 0 1,7

fillseq_cmd="numactl --cpubind=0 --membind=0 /rocksdb/db_bench --benchmarks="fillseq,stats" --statistics --db=./db_bench_test --key_size=16 --value_size=256 \
--block_size=4096 --num=100000000 --bloom_bits=10 --compression_ratio=0.25 --compression_type=com.intel.iaa_compressor_rocksdb \
--compressor_options="execution_path=${METHOD}" --disable_wal=true"

readrandom_cmd="numactl --cpubind=0 --membind=0 /rocksdb/db_bench --benchmarks="readrandom,stats" --disable_auto_compactions=1 --use_existing_db=1 \
--db=./db_bench_test --wal_dir=./db_bench_test --key_size=16 --value_size=256 --compression_type=com.intel.iaa_compressor_rocksdb --compressor_options="execution_path=${METHOD}" --num=100000000 --duration=500 \
--reads=4000000 --threads=30 --block_size=4096 --compression_ratio=0.25 --memtablerep=skip_list --cache_size=-1 --bloom_bits=10 \
--use_direct_reads=0 --use_direct_io_for_flush_and_compaction=0 --verify_checksum=1 --stats_per_interval=1 --row_cache_size=0 \
--compressed_cache_size=-1 --use_cache_memkind_kmem_allocator=false --cache_index_and_filter_blocks=false --cache_numshardbits=6 \
--stats_interval_seconds=60 --histogram=1"

readrandomwriterandom_cmd="numactl --cpubind=0 --membind=0 /rocksdb/db_bench  --benchmarks=readrandomwriterandom --disable_auto_compactions=1 --use_existing_db=1 \
--db=./db_bench_test --wal_dir=./db_bench_test --key_size=16 --value_size=256 --compression_type=com.intel.iaa_compressor_rocksdb --compressor_options="execution_path=${METHOD}" --readwritepercent=80 --num=100000000 \
--duration=480 --threads=30 --max_write_buffer_number=40 --write_buffer_size=1073741824 --block_size=4096 --compression_ratio=0.25 \
--max_background_jobs=12 --subcompactions=8 --memtablerep=skip_list --cache_size=-1 --cache_numshardbits=6 --bloom_bits=10 \
--use_direct_reads=0 --use_direct_io_for_flush_and_compaction=0 --verify_checksum=1 --stats_per_interval=1 --stats_interval_seconds=60 --histogram=1"

if [[ $TYPE == "fillseq" ]]; then
    set -x
    $fillseq_cmd | tee out.logs
    set +x
elif [[ $TYPE == "readrandom" ]]; then
    # randread
    set -x
    $fillseq_cmd
    $readrandom_cmd | tee out.logs
    set +x
elif [[ $TYPE == "readrandomwriterandom" ]]; then
    set -x
    $fillseq_cmd
    $readrandomwriterandom_cmd | tee out.logs
    set +x
fi


num=`cat out.logs | grep -F "WARNING: com.intel.iaa_compressor_rocksdb compression is not enabled" | wc -l`
if [[ $nums -gt 0 ]]; then
    exit 1
fi

