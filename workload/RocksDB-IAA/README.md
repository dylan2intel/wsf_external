### Introduction

RocksDB is developed and maintained by Facebook Database Engineering Team. The Intel® In-Memory Analytics Accelerator (IAA) plugin for RocksDB provides accelerated compression/decompression in RocksDB using IAA and QPL (Query Processing Library). It has a number of tests that are available to be run.

Requirements for this workload Linux kernel version 5.18 or later.

#### IAA compressor
There are currently testcases that measure Intel IAA compressor performance.
* `test_*_db_bench_rocksdbiaa_readrandom_pkm` - PKM Testcase
   1. This testcase is the PKM Testcase.
   2. This testcase is random with IAA compressor testcase
* `test_*_db_bench_rocksdbiaa_randomreadrandomwrite_pkm` - PKM Testcase
   1. This testcase is the PKM Testcase.
   2. This testcase is random read and write with IAA compressor testcase
* `test_*_db_bench_rocksdbiaa_readrandom_gated` - Gated Testcase
   1. This testcase is the Gated Testcase.


### Zstd compressor
There are currently testcases that measure Zstd compressor performance.
* `test_*_db_bench_rocksdbiaa_zstd_readrandom`
   1. This testcase is random with Zstd compressor testcase
* `test_*_db_bench_rocksdbiaa_zstd_randomreadrandomwrite` - PKM Testcase
   1. This testcase is random read and write with Zstd compressor testcase


### Test Case
The workload organizes the following test cases:
- `gated`: This test case validates the workload feature.
- `pkm`: This test case is with performance analysis.

### Workload Configuration
The workload exposes below variables, which can be configured:

- **`TYPE`**: readrandomoperands,backup,restoreComma-separated list of operations to run in the specified order..
- **`KEY_SIZE`**: Size of each key.
- **`VALUE_SIZE`**:  Size of each value in fixed distribution.
- **`BLOCK_SIZE`**: Number of bytes in a block.
- **`THREADS_NUM`**: Number of concurrent threads to run.


Follow below steps to run the workload:

```
# Config CPS(e.g. static) and build the image
cd build
cmake -DBACKEND=terraform -DTERRAFORM_SUT=static
make alicloud
aliyun configure # please specify a region and output format as json
cd workload/RocksDB-IAA-Cloud
make
./ctest.sh -N # list test cases

# Run all test cases
./ctest.sh -V

```

### KPI
The following KPI is defined:
- `throughput`：ops per sec
- `p99`: the 99th percentile of the RocksDB read or write latency distribution
Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs.

### Config IAA Device on host
The configuration of the IAA device has been done automatically in workload, in order to support the use of the IAA device in the container but there is still some work to be performed manually.
```
EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable
EDKII Menu → Socket Configuration → IIO Configuration → PCI ENQCMD/ENQCMDS → Yes
```
The VT-d must be enabled from the kernel command line.
```
sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"
sudo reboot
```

### Contact

- Stage1 Contact: `Longtan Li`; `Junlai Wang`
- Validation: `Yanping Wu`
- Stage2 Contact: `Giacchino, Luca`

### Index Info
- Name: `RocksDB IAA`
- Category: `DataServices`
- Platform: `SPR` `EMR`
- Keywords: `Cloud`, `RocksDB`, `IAA`
- Permission:

### Config IAA Device on host
The BIOS must be configured with VT-d and PCI ENQCMD enabled, as follows:
```
EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable
EDKII Menu → Socket Configuration → IIO Configuration → PCI ENQCMD/ENQCMDS → Yes
```
The VT-d must be enabled from the kernel command line.
```
sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"
sudo reboot
```
### Validation Notes
- Validated with release [`v23.17.6`](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/releases/tag/v23.17.6) on `SPR`, passed on platform `SPR`.
- Known Issues:
  - None.

### See Also

- [`RocksDB | A persistent key-value store | RocksDB`](https://rocksdb.org/)
- [`Getting started | RocksDB`](https://rocksdb.org/docs/getting-started.html#:~:text=Getting%20started%201%20Overview%20The%20RocksDB%20library%20provides,Reads%20And%20Writes%20...%206%20Further%20documentation%20)
- [`Github:  facebook/rocksdb `](https://github.com/facebook/rocksdb/)
- [`RocksDB* Tuning Guide on Intel® Xeon® Processor Platforms`](https://www.intel.com/content/www/us/en/developer/articles/guide/rocksdb-tuning-guide-on-xeon-based-system.html)
