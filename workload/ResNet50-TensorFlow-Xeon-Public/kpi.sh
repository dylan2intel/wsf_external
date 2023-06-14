#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk -F ', |: |; ' '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.\[\]]+ *(.*)/, "\\1", 1, value);
    value=gensub(/^([0-9+-.]+).*/, "\\1", 1, value);
    key=gensub(/(.*): *$/, "\\1", 1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
function getvalue(value) {
    if (value=="'\'''\''") {
        value="-1"
    }
    return value;
}
BEGIN {
    framework="-1"
    tensorflow="unknown"
    onednn="3.1.0 (not read)"
    model_name="ResNet50"
    model_size="-1"
    model_source="IntelModelZoo"
    dataset="ImageNet"
    scenario="Offline"

    fu="-1"
    mode="-1"
    precision="-1"
    data_type="-1"
    batch_size="-1"
    steps="-1"
    test_time="-1"
    cores_per_instance="-1"
    inst_num="-1"
    train_epoch="-1"
    
    serving_stack="-1"
    model_workers="-1"
    request_per_worker="-1"
    
    accuracy="-1"
    average_throughput="-1"
    max_latency="-1"
    min_latency="-1"
    mean_latency="-1"
    p50_latency="-1"
    p90_latency="-1"
    p95_latency="-1"
    p99_latency="-1"
    p999_latency="-1"
    ttt="-1"
    samples="-1"
    compute_utilization="-1"
    memory_utilization="-1"
    flops="-1"
    model_quality_metric_name="-1"
    model_quality_value="-1"
    cost_per_million_inferences="-1"
    total_throughput="-1"
    la_sum_inf=0
    i=0
    j=0
    print_not_all_instances=0
}
/^TensorFlow_Version:/ {
   tensorflow=$2
}
# works only when verbose
/^onednn_verbose,info,oneDNN v/{
    onednn=$2
}
/^MODE/ {
   mode=$2
}
/^TOPOLOGY/{
   model_name=$2
}
/^FUNCTION/ {
   fu=$2
}

/^PLATFORM/{
   PLATFORM=$2
}

/^PRECISION/ {
   precision=$2
   if ( precision == "amx_bfloat16" && PLATFORM == "GENOA") {
    precision="avx_bfloat16"
   }
}

/^BATCH_SIZE/ {
   batch_size=$2
}
/^STEPS/ {
   steps=$2
}
/^DATA_TYPE/ {
   data_type=$2
}
/^CORES_PER_INSTANCE/ {
   cores_per_instance=$2
}
/Throughput:/ {
    throughput=$2
    if ( throughput - th_instances[i] > 0 ){
        th_instances[i]=throughput
        i+=1
    }
}
# when mode!=latency
/Latency:/ {
    latency=$2
    if ( latency - la_instances[j] > 0 ){
        la_instances[j]=latency
        j+=1
    }
}
# when mode=latency
/^Instance num/{
    split($0, temp_lat_arr, " ")
    latency=temp_lat_arr[6]

    if ( latency - la_instances[j] > 0 ){
        la_instances[j]=latency
        j+=1
    }
}

/Processed 50000 images./ {
    accuracy=gensub("\x29", "", "g", $NF)
}
/^Killed/ {
    print_not_all_instances=1
}

END {
    for ( n in th_instances ) {
        total_throughput+=th_instances[n]
    }
    if ( batch_size == "1" ) {
        for ( n in la_instances ) {
            mean_latency+=la_instances[n]
        }
        if ( j > 0 ){
            mean_latency=mean_latency/j
        }
    }
    print "\n#================================================"
    print "#Workload Configuration"
    print "#================================================"
    print "##FRAMEWORK: TensorFlow "tensorflow", oneDNN "onednn
    print "##MODEL_NAME: "model_name
    print "##MODEL_SIZE: "model_size
    print "##MODEL_SOURCE: "model_source
    print "##DATASET: "dataset
    print "##FUNCTION: "fu
    print "##MODE: "mode
    print "##PRECISION: "precision
    print "##DATA_TYPE: "data_type
    print "##BATCH_SIZE: "batch_size
    if (framework == "OpenVINO") {
        print "##Test Time (s): "ttt
    }
    else {
        print "##STEPS: "steps
    }
    print "##INSTANCE_NUMBER: "i
    print "##CORES_PER_INSTANCE: "cores_per_instance
    print "##TRAIN_EPOCH: "train_epoch
    
    print "\n#================================================"
    print "#Application Configuration"
    print "#================================================"
    print "##SCENARIO: "scenario
    print "##SERVING_STACK: "serving_stack
    print "##MODEL_WORKERS: "model_workers
    print "##REQUEST_PER_WORKER: "request_per_worker

    print "\n#================================================"
    print "#Metrics"
    print "#================================================"
    average_throughput="-1"
    if ( i != 0 ){
        average_throughput=total_throughput/i
    }
    print "Average Throughput (samples/sec): "average_throughput
    print "Average Latency (ms): "mean_latency
    print "Max Latency (ms): "max_latency
    print "Min Latency (ms): "min_latency
    print "P50 Latency (ms): "p50_latency
    print "P90 Latency (ms): "p90_latency
    print "P95 Latency (ms): "p95_latency
    print "P99 Latency (ms): "p99_latency
    print "P999 Latency (ms): "p999_latency
    print "TTT (s): "ttt
    print "Samples: "samples
    print "Compute Utilization: "compute_utilization
    print "Memory Utilization: "memory_utilization
    print "FLOPs: "flops
    print "Model Quality Metric Name: "model_quality_metric_name
    print "Model Quality Value: "model_quality_value
    print "Cost Per Million Inference: "cost_per_million_inferences

    print "\n#================================================"
    print "#Key KPI"
    print "#================================================"
    if ( mode == "accuracy" ){
        print kvformat("*""accuracy", accuracy*100 "%")
    }
    else if ( mode == "throughput" ){
        
        print kvformat("*""throughput",total_throughput "images/sec")
    }
    else {
        print kvformat("*""average latency",mean_latency "msec/batch")
    }
    if ( print_not_all_instances == 1 ){
        print "#INVALID RESULT: Some instances were killed during execution! See README.md for more."
    }
}
' */benchmark_*.log 2>/dev/null || true
