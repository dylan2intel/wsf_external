### Introduction

ResNet50 is a variant of ResNet model which has 48 Convolution layers along with 1 MaxPool and 1 Average Pool layer. It has 3.8 x 10^9 Floating points operations. It is a widely used ResNet model and we have explored ResNet50 architecture in depth.

- **DATASET**：http://image-net.org/challenges/LSVRC/2012/
- **MODEL_WEIGHTS**: https://zenodo.org/record/2535873/files/resnet50_v1.pb
- **BENCHMARK_SCRIPT**: https://github.com/IntelAI/models/tree/spr-launch-public/quickstart/image_recognition/tensorflow/resnet50v1_5

### Parameters

The Resnet50 workload provides test cases with the following configuration parameters:
- **FUNCTION**: Specify which workload should run: `inference`.
- **MODE**: Specify the running mode: `latency`, `throughput` or `accuracy`.
  * `latency`: For performance measurement only. 4 cores per test instance, KPI counts on all test instances result together.
  * `throughput`: For performance measurement only. 1 socket per test instance, KPI counts on all test instances result together.
  * `accuracy`: For accuracy measurement only.
- **CASE_TYPE**: This is optional parameter, specify `gated` or `pkm`.  
  - `gated` represents running the workload with reduced parameters: `STEPS=10`, `BATCH_SIZE=1` and `CORES_PER_INSTANCE=$CORES_PER_SOCKET`.
  - `pkm` represents running the workload with the common parameters.
- **PRECISION**: Specify the model precision: `avx_int8`, `avx_fp32`, `amx_int8`, `amx_bfloat16`, or `amx_bfloat32`. For GENOA platform `avx_bloat16` precision is supported.
- **DATA_TYPE**: Specify the input/output data type: `dummy` or `real`.
- **BATCH_SIZE**: Specify the size of batch: `--batch_size=1` or empty to set the default values.
- **CORES_PER_INSTANCE**: Specify the number of cores per instance: `--cores_per_instance=4` or empty to set the default values.
- **STEPS**: Specify the step value: `--steps=10` or empty to set the default values.
- **WEIGHT SHARING**: Add the parameter: `--weight_sharing` if want to use weight sharing. Precision `avx_fp32` and `amx_bfloat32` are not supported weight sharing.
- **VERBOSE**: Specify if want to use IntelAI model zoo verbose default as `False`.
- **ONEDNN_VERBOSE**: Specify if print the oneDNN information default as `False`. 
- **MPI**: Message Passing Interface is an interface for parallel computing based on message passing models.
- **NUM_MPI**: Specify how many MPI processes to launch per socket.
- **CUSTOMER_ENV**: Users can customize the environment variables that need to be set, which can be used in conjunction with `ctest --set "CUSTOMER_ENV=<ENV_NAME_1>=<VALUE_1> <ENV_NAME_2>=<VALUE_2> <ENV_NAME_3>=<VALUE_3>"`

```
  Note: The KPI depends on the CPU SKU, core count, cache size and memory capacity/performance, etc.
```

### Test Case

The test case name is a combination of `<FUNCTION>-<MODE>-<PRECISION>-<CASE_TYPE>` (CASE_TYPE is optional). Use the following commands to list and run test cases through service framework automation pipeline:
```
cd build
cmake ..
cd workload/ResNet50-TensorFlow-Xeon-Public
./ctest.sh -N (list all designed test cases)

(eg. on SPR)
  Test  #1: test_resnet50v1_5_tensorflow_xeon_public_inference_throughput_amx_bfloat16
  Test  #2: test_resnet50v1_5_tensorflow_xeon_public_inference_latency_amx_bfloat16
  Test  #3: test_resnet50v1_5_tensorflow_xeon_public_inference_accuracy_amx_bfloat16
  Test  #4: test_resnet50v1_5_tensorflow_xeon_public_inference_throughput_amx_bfloat16_gated
  Test  #5: test_resnet50v1_5_tensorflow_xeon_public_inference_throughput_amx_bfloat16_pkm
  Test  #6: test_resnet50v1_5_tensorflow_xeon_public_sgx_inference_throughput_amx_bfloat16
  Test  #7: test_resnet50v1_5_tensorflow_xeon_public_sgx_inference_latency_amx_bfloat16
  Test  #8: test_resnet50v1_5_tensorflow_xeon_public_sgx_inference_accuracy_amx_bfloat16
  Test  #9: test_resnet50v1_5_tensorflow_xeon_public_sgx_inference_throughput_amx_bfloat16_gated
  Test #10: test_resnet50v1_5_tensorflow_xeon_public_sgx_inference_throughput_amx_bfloat16_pkm

or
./ctest.sh -V (run all test cases)
```

### System Requirements

Requires ~1TB of disk space available during runtime. See [AI Setup](../../doc/setup-ai.md) for more system setup instructions.
For latency mode, physical CPU number should be equal or larger than 4.

To setup SGX, See [setup-gramine-sgx.md](../../doc/setup-gramine-sgx.md#node-labels) for more details.

#### Downloading datasets

> **Note:** Do not push any dataset archives to the repository.

Information about dataset files are present below
* File name: `ILSVRC2012_img_val.tar`
* SHA-256: `c7e06a6c0baccf06d8dbeb6577d71efff84673a5dbdd50633ab44f8ea0456ae0`  
* MD5: `29b22e2961454d5413ddabcf34fc5622`  
* Size: `6744924160` B = ~6.3 GB  
* External link: https://image-net.org/data/ILSVRC/2012/ILSVRC2012_img_val.tar

Files can be downloaded locally to `/dataset` folder before build, or during build. When first option is used, remember to uncomment marked commented lines from `Dockerfile.3.inference-dataset` Dockerfiles,

from
```Dockerfile
# To copy local file from /dataset
# instead of downloading, uncomment below lines
# COPY dataset/$DATASET_FILE_NAME /dataset
# ARG TRIES="5"
# ----
```

to
```Dockerfile
# To copy local file from /dataset
# instead of downloading, uncomment below lines
COPY dataset/$DATASET_FILE_NAME /dataset
ARG TRIES="5"
# ----
```

#### Checking validity of datasets

When the files are downloaded locally, use `md5sum` or `sha256sum` tools to check their checksums and compare with above. Size in bytes is also provided for additional context.

### Docker Image

The ResNet50 workload provides 6 docker images:
- `resnet50v1_5-tensorflow-inference-dataset` - inference dataset.
- `resnet50v1_5-tensorflow-model` - fp32, bfloat16, int8 model.
- `resnet50v1_5-tensorflow-benchmark` - Intel public benchmark script.
- `ai-resnet50v1_5-tensorflow-intel-public-inference` - inference.

The ResNet50 SGX workload provides 1 docker images:
- `ai-resnet50v1_5-tensorflow-intel-public-inference-sgx` - inference.

Test case with DATA_TYPE specified as `dummy` will be automatically run on `ai-resnet50v1_5_tensorflow_xeon_public-inference-dummy` image. Test case with DATA_TYPE specified as `real` will be automacitally run on `ai-resnet50v1_5_tensorflow_xeon_public-inference-real` image. To run the workload, provide the set of environment variables described in the [Test Case](#Test-Case) section as follows:

```
mkdir -p logs-latency-avx-fp32-inference-dummy
id=$(docker run --rm --detach --privileged -e WORKLOAD=resnet50v1_5_tensorflow_xeon_public -e PLATFORM=SPR -e MODE=throughput -e TOPOLOGY=resnet50v1_5 -e FUNCTION=inference -e PRECISION=avx_fp32 -e BATCH_SIZE=64 -e STEPS=100 -e DATA_TYPE=dummy -e CORES_PER_INSTANCE=56 -e WEIGHT_SHARING=False -e CASE_TYPE= -e VERBOSE=False -e INSTANCE_MODE=flex ai-resnet50v1_5-inference-dummy:latest)
docker exec $id cat /export-logs | tar xf - -C logs-latency-avx-fp32-inference-dummy
docker rm -f $id
```

### KPI

Run the [kpi.sh](kpi.sh) script to parse the KPIs from the validation logs. The script takes the following command line argument:

```
Usage: make_kpi_resnet50v1_5
```

The ResNet50 workload produces a single KPI:
- **Throughput**: The model throughput value.
- **Latency**: The model latency value.
- **Accuracy**: The model accuracy value, a percentage.

> **Note:** When `#INVALID RESULT: Some instances were killed during execution! See README.md for more.` is visible in the results,
 there are instances which have not produced results. The final result is insignificant due to such disruption.
 In order to resolve, align `CORES_PER_INSTANCE` parameter with your hardware, so the instances fit into memory.

### Performance BKM
- Minimum system setup: SPR or newer required for AMX tests
- Recommended system setup: 512 GB RAM
- Workload parameter tuning guidelines:
  - Batch Size (BS) and Cores per Instance (CPI) - key parameters of the workload​
  - Full sweep for various BS and CPI
  - For performance comparison get max throughput for each BS and compare

Performance report results summary for throughput tests (maximum samples per second):
| precision    | BS  | CPI | CPU | value |
| ------------ | ---:| ---:| --- | -----:|
| amx_int8     | 64  |  14 | SPR | 13460 |
| amx_bfloat16 | 32  |  14 | SPR | 7462  |
| avx_int8     | 32  |  7  | SPR | 5514  |
| avx_fp32     | 128 |  4  | SPR | 1451  |

### Index Info
- Name: `ResNet-50, TensorFlow`
- Category: `ML/DL/AI`
- Platform: `GNR`, `SPR`, `ICX`, `SRF`, `EMR`, `GENOA`
- Keywords: `AMX`, `TMUL`, `SGX`
- Permission:

### Validation Notes

- Validated with release [`v22.53`](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/releases/tag/v22.53) on `SPR`, `ICX`, `SPR_VM`, `SPR_GCP`, `ICX_AWS`, passed on platform `SPR`,`ICX`,`SPR_VM`,`SPR_GCP`,`ICX_AWS` .

### See Also

- [Intel AI Model Zoo](https://github.com/IntelAI/models/tree/spr-launch-public)  
