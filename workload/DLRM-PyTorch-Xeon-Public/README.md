### Introduction

The DLRM is a popular Neural Network for recommendation, its full name is Deep Learning Recommendation Model (DLRM). The core idea of the model is to capture the relative interest of the recommended items by using the historical behavior data for the user under the background of diversified user interests. DLRM can help us build recommendation systems to predict what users might like, especially when there are lots of choices available. DLRM-ARM Workload in our framework provides a competitive optimized methodologies for benchmark from ARM platform.

- **DATASET**：https://ailab.criteo.com/criteo-1tb-click-logs-dataset-for-mlperf/ *read and **accept** the use terms and conditions via the link*, then go to [download page](https://criteo.wetransfer.com/downloads/4bbea9b4a54baddea549d71271a38e2c20230428071257/d4f0d2/grid) to proceed downloading.
*Hint: please download and place the dataset(day0.gz) under /path/to/wsf/workload/DLRM-PyTorch-Xeon-Public/dataset/ in prior. If you have any concern, please check [Dockerfile.3.dataset](Dockerfile.3.dataset) for detailed instructions*
- **MODEL_WEIGHTS**: https://dlrm.s3-us-west-1.amazonaws.com/models/tb00_40M.pt"
- **BENCHMARK_SCRIPT**: https://github.com/IntelAI/models/blob/master/models/recommendation/pytorch/dlrm/product/dlrm_s_pytorch.py

### Parameters

The DLRM workload provides test cases with the following configuration parameters:
- **MODE**: Specify the running mode: `latency`, `throughput` or `accuracy`.  
  * `latency`: For performance measurement only. 4 cores per test instance, KPI counts on all test instances result together. Only valid of `inference`.
  * `throughput`: For performance measurement only. 1 socket per test instance, KPI counts on all test instances result together.
  * `accuracy`: For accuracy measurement only. Only valid for `inference`.
```
  Note: The KPI depends on the CPU SKU,core count,cache size and memory capacity/performance, etc.
```
- **PRECISION**: Specify the model precision: `avx_int8`, `avx_fp32`, `amx_int8`, `amx_bfloat16` or `amx_bfloat32`. Default one is `avx_fp32`. For GENOA platform `avx_bfloat16` precision is supported. (Note: `amx` precisions are not supported when `PLATFORM=ICX`) 
- **FUNCTION**: Specify whether the workload should run: `inference`, `training`.
- **DATA_TYPE**: Specify the input/output data type: `real`. 
- **CASE_TYPE**: This is an optional parameter, specify `gated` or `pkm`.  Please refer to more details about [case type](../../doc/user-guide/executing-workload/testcase.md).
- **BATCH_SIZE**: Specify the batch size value: default as `BATCH_SIZE=1` for inference throughput/latency, `BATCH_SIZE=1024` for training and `BATCH_SIZE=100` for inference accuracy.
- **WARMUP_STEPS**: Specify the number of steps for warming purpose before entering the formal stage. (`default=0` not support change)
- **STEPS**: Specify the inference steps value: default as `STEPS=200`. This parameter is not tunable using accuracy case. (Note: make sure the `STEPS` large enough when the `BATCH_SIZE` is small, or may meet `division by zero` error.)
- **CORES_PER_INSTANCE**: Define the number of cores in one instance. Default as `cores per numa node`.
- **INSTANCE_NUMBER**: Define the number of instances. This value is calculated using `total cores/CORES_PER_INSTANCE` so far, and default as `number of numa nodes`.
- **WEIGHT_SHARING**: dafault value set to `True`. This parameter is case sensitive, possible values are: `True`, `False`. (For DLRM, inference throughput must turn **on** WEIGHT_SHARING and training must turn **off** WEIGHT_SHARING)
- **ONEDNN_VERBOSE**: Specify if print the oneDNN information `default` as `0`.

### Test Case

The test case name is a combination of `<WORKLOAD>_<FUNCTION>_<MODE>_<PRECISION>_<CASE_TYPE>` (CASE_TYPE is optional). Use the following commands to list and run test cases through service framework automation pipeline:
```
cd build
cmake ..
cd workload/DLRM-Pytorch-Xeon-Public
./ctest.sh -N (list all designed test cases)

or
./ctest.sh -V (run all test cases)

Test cases:
  Test #1: test_dlrm_pytorch_xeon_public_inference_throughput_amx_bfloat16
  Test #2: test_dlrm_pytorch_xeon_public_inference_throughput_amx_bfloat16_gated
  Test #3: test_dlrm_pytorch_xeon_public_inference_throughput_amx_bfloat16_pkm
  Test #4: test_dlrm_pytorch_xeon_public_inference_accuracy_amx_bfloat16
  Test #5: test_dlrm_pytorch_xeon_public_training_throughput_amx_bfloat16
  Test #6: test_dlrm_pytorch_xeon_public_training_accuracy_amx_bfloat16
```

### System Requirements

Requires ~1TB of disk space available during runtime. See [AI Setup](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for more system setup instructions.
For latency mode, physical CPU number should be equal or larger than 4.

### Docker Image

The DLRM workload provides 6 docker images:
- `dlrm-pytorch-dataset` - inference & training dataset.
- `dlrm-pytorch-model` - fp32, bfloat16, int8 model.
- `dlrm-pytorch-benchmark` - Intel public benchmark script.
- `dlrm-pytorch-intel-public-inference` - inference throughput/latency
- `dlrm-pytorch-intel-public-inference-accuracy` - inference accuracy
- `dlrm-pytorch-intel-public-training` - training throughput/accuracy

#### build docker image from scrach
do cmake and make to build a specific workload
Please refer to [cmake doc](../../doc/user-guide/executing-workload/cmake.md) and [How to build a specific workload only](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/wiki/FAQ)

To run the workload, provide the set of environment variables described in the [Test Case](#Test-Case) section as follows:
```
mkdir -p logs-dlrm_pytorch_xeon_public_inference_throughput_amx_bfloat16
id=$(docker run --detach --rm --privileged -e TOPOLOGY=dlrm -e MODE=throughput -e PRECISION=amx_bfloat16 -e FUNCTION=inference -e DATA_TYPE=real -e BATCH_SIZE=16 -e STEPS=330 dlrm-pytorch-intel-public-inference)    
docker exec $id cat /export-logs | tar xf - -C logs-dlrm_pytorch_xeon_public_inference_throughput_amx_bfloat16
docker rm -f $id
```

### KPI

Run the [`list-kpi.sh`](../../doc/user-guide/executing-workload/ctest.md#list-kpish) script to parse the KPIs from the validation logs. 

KPI output example:
```
#================================================
#Key KPI
#================================================
*Throughput (samples/sec): 113186.18
```
Refer to [AI](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for more KPI details.

### Performance BKM

### Index Info
- Name: `Deep Learning Recommendation Model`  
- Category: `ML/DL/AI`  
- Platform: `ICX` `SPR` 
- Keywords:   
- Permission:  

### See Also

- [Intel AI Model Zoo](https://github.com/IntelAI/models/tree/spr-launch-public)