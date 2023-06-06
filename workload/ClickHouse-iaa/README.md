### Introduction

ClickHouse® is a column-oriented database management system (DBMS) for online analytical processing of queries (OLAP). This benchmark is based on a [Star Schema Benchmark](https://clickhouse.com/docs/en/getting-started/example-datasets/star-schema) from official ClickHouse web page. Especially this benchmark is exercising Intel In-Memory Analytics Accelerator (IAA) through hardware-assisted codec.  

### Test Case

There are two defined test cases:
- `hardware_benchmark`: Test runs all queries in `ssbqueries.sql` file; each query is run 3 times (first run is with cold cache, rest are run while cache is hot)
- `hardware_benchmark_gated`: This test case uses a small subset of queries from `ssbqueries.sql` specified in `ssbqueries_gated.sql`.

### Docker Image

The workload contains two dockers images: `clickhouse-iaa-server` and `clickhouse-iaa-benchmark`.  Benchmark can be run using either Kubernetes or Docker as a backend. Running test on IAA-enabled Host using Docker is as follows (if the IAA is not well set up in the host, it falls back to software codec)
```
mkdir -p logs
server=$(docker run --rm --detach --privileged --network host clickhouse-iaa-server)
id=$(docker run --rm --detach --privileged --network host -e TESTCASE=test_clickhouse_iaa_hardware_benchmark_gated clickhouse-iaa-benchmark)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id $server
```
There is another docker image clickhouse-iaa-ssb which integrates the Clickhouse server and client in a single container. Example to run the single container is as follows, which mount the host dev directory to the container's dev directory, as a showcase to self-enable IAX devices (assume BIOS and kernel has been well set up) to support the hardware-assisted codec:
```
docker run --rm --detach --privileged -v /dev:/dev --network host -e TESTCASE=test_clickhouse_iaa_hardware_benchmark clickhouse-iaa-ssb
```

### Config IAA Device on host

The BIOS must be configured with VT-d and PCI ENQCMD enabled, as follows:
```
EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable
EDKII Menu → Socket Configuration → IIO Configuration → PCI ENQCMD/ENQCMDS → Yes
```
The VT-d must be enabled from the kernel command line, which can be checked with the output of intel_iommu from "cat /proc/cmdline":
```
sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"
sudo reboot
```
The IAA devices need to be enabled as well. The enabling commands can be done by the host or can be integrated to the docker image. "-v /dev:/dev" is needed as docker run option if the docker is supposed to enable the host IAA device. Below are the commands to enable 4 IAA devices:
```
accel-config load-config -c ./accel-iaa-4d1g8e.conf
accel-config enable-device iax1
accel-config enable-wq iax1/wq1.0
accel-config enable-device iax3
accel-config enable-wq iax3/wq3.0
accel-config enable-device iax5
accel-config enable-wq iax5/wq5.0
accel-config enable-device iax7
accel-config enable-wq iax7/wq7.0
```
  
### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs.
The following KPI are defined:

- `Geomean_query_latency_(s)`: Geometric mean of all ran queries latency in seconds (This is the primary KPI).
- `Cold_cache_geomean_query_latency_(s)`: Geometric mean of all ran queries latency in seconds with cold cache.
- `Hot_cache_geomean_query_latency_(s)`: Geometric mean of all ran queries latency in seconds with hot cache.

### See Also 

- [What is ClickHouse?](https://clickhouse.com/docs/en/intro)
- [ClickHouse Star Schema Benchmark](https://clickhouse.com/docs/en/getting-started/example-datasets/star-schema)
- [Intel(R) In-Memory Analytics Accelerator Architecture Specification](https://cdrdv2-public.intel.com/721858/350295-iaa-specification.pdf)
