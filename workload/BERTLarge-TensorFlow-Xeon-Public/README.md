
### Introduction

This workload is targeting for **BERT Large** benchmarking using TensorFlow framework on Intel Xeon.

**BERT** stands for Bidirectional Encoder Representation for Transformers. BERT represents a set of state-of-art deep learning models that can perform a wide variety of natural language processing tasks. **BERT Large** is one of the BERT models that has 24 layers, 16 attention heads, and totally 340 million parameters. This version of **BERT Large** uses TensorFlow framework.

- **DATASET**：https://rajpurkar.github.io/SQuAD-explorer/dataset/dev-v1.1.json
- **MODEL_WEIGHTS**:
  * uncased model: https://storage.googleapis.com/bert_models/2019_05_30/wwm_uncased_L-24_H-1024_A-16.zip
  * FP32: https://storage.googleapis.com/intel-optimized-tensorflow/models/2_10_0/fp32_bert_squad.pb
  * BFloat16: https://storage.googleapis.com/intel-optimized-tensorflow/models/2_10_0/optimized_bf16_bert.pb
- **BENCHMARK_SCRIPT**: https://github.com/IntelAI/models/blob/master/models/language_modeling/tensorflow/bert_large/inference/run_squad.py

### Parameters

The BERT Large workload provides test cases with the following configuration parameters:
- **MODE**: Specify the running mode: `latency`, `throughput` or `accuracy`.
  * `latency`: For performance measurement only. 4 cores per test instance, KPI counts on all test instances result together. Only valid of `inference`.
  * `throughput`: For performance measurement only. 1 socket per test instance, KPI counts on all test instances result together.
  * `accuracy`: For accuracy measurement only. Only valid for `inference`.
```
  Note: The KPI depends on the CPU SKU,core count,cache size and memory capacity/performance, etc.
```
- **PRECISION**: Specify the model precision: `avx_fp32`, `amx_bfloat16`. Default one is `avx_fp32`. For GENOA platform `avx_bfloat16` precision is supported. (Note: `int8` precisions are not supported)
- **FUNCTION**: Specify whether the workload should run: `inference`, `training`(not support).
- **DATA_TYPE**: Specify the input/output data type: `real`.
- **CASE_TYPE**: This is an optional parameter, specify `gated` or `pkm`.  Please refer to more details about [case type](../../doc/user-guide/executing-workload/testcase.md).
- **BATCH_SIZE**: Specify the batch size value: default as `BATCH_SIZE=1`.
- **WARMUP_STEPS**: Specify the number of steps for warming purpose before entering the formal stage.
- **STEPS**: Specify the inference steps value: default as `STEPS=1`. This parameter is not tunable using accuracy case. (Note: make sure the `STEPS` large enough when the `BATCH_SIZE` is small, or may meet `division by zero` error.)
- **CORES_PER_INSTANCE**: Define the number of cores in one instance. Default as `cores per numa node`.
- **INSTANCE_NUMBER**: Define the number of instances. This value is calculated using `total cores/CORES_PER_INSTANCE` so far, and default as `number of numa nodes`.
- **WEIGHT_SHARING**: dafault value set to `False`. This parameter is case sensitive, possible values are: `True`, `False`.
- **MAX_SEQ_LENGTH**: Specify the maximum length of the input sequence of the model.
- **ONEDNN_VERBOSE**: Specify if print the oneDNN information `default` as `0`.

### Test Case

They are built-in test cases for `ctest`. The test case name is a combination of `<WORKLOAD_NAME>-<MODE>-<FUNCTION>-<PRECISION>`. Not all combinations are supported.

> Additionally, the test cases with suffix `_gated` represents running the workload with reduced steps: `STEPS=1`.

Use the following commands to show the list of test cases:
```
cd build
cmake ..
cd workload/BERTLarge-TensorFlow-Xeon-Public
./ctest.sh -N

or
./ctest.sh -V
(run all test cases)

or
./ctest.sh -R <test case key word> -V
(run specific test case(s), i.e. `./ctest.sh -R pkm -V` to run PKM test cases. This will use default parameter to run cases, such as BATCH_SIZE=1, STEPS=10, PRECISION=avx_fp32)

Test cases:
  Test #1: test_bertlarge-tensorflow-xeon-public_inference_throughput_amx_bfloat16
  Test #2: test_bertlarge-tensorflow-xeon-public_inference_latency_amx_bfloat16
  Test #3: test_bertlarge-tensorflow-xeon-public_inference_accuracy_amx_bfloat16
  Test #4: test_bertlarge-tensorflow-xeon-public_inference_throughput_amx_bfloat16_gated
  Test #5: test_bertlarge-tensorflow-xeon-public_inference_throughput_amx_bfloat16_pkm
```

### Docker Image

The BERT Large workload provides 1 docker image: `bertlarge-tensorflow-xeon-public-inference`.

#### build docker image from scrach
do cmake and make to build a specific workload
Please refer to [cmake doc](../../doc/user-guide/executing-workload/cmake.md)

To run the workload, provide the set of environment variables described in the [Test Case](#Test-Case) section as follows:
```
mkdir -p logs-throughput-amx-bfloat16-inference
id=$(docker run --detach --rm --privileged -e TOPOLOGY=bert_large -e MODE=throughput -e PRECISION=amx_bfloat16 -e FUNCTION=inference -e DATA_TYPE=real -e BATCH_SIZE=16 -e STEPS=330 bertlarge-tensorflow-xeon-public-inference)
docker exec $id cat /export-logs | tar xf - -C logs-throughput-amx-bfloat16-inference
docker rm -f $id
```

### Minimal Requirment

The minimum memory for this workload is `12 GB per instance (>=1)`

### KPI

Run the [`list-kpi.sh`](../../doc/user-guide/executing-workload/ctest.md#list-kpish) script to parse the KPIs from the validation logs.

KPI output example:
```
#================================================
#Key KPI
#================================================
*Throughput (samples/sec): 86.13
```

### Index Info
- Name: `Bert Large, TensorFlow`
- Category: `ML/DL/AI`
- Platform: `SPR`, `ICX`
- Keywords: `AVX`, `AMX`

- Known Issues:
  - None

### See Also
- [State-of-the-art BERT Fine-tune training and Inference](https://intel.github.io/stacks/dlrs/bert-performance.html)
