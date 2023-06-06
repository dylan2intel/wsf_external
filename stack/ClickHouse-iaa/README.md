### Introduction

ClickHouse® is a column-oriented database management system (DBMS) for online analytical processing of queries (OLAP). Especially this software stack is exercising Intel In-Memory Analytics Accelerator (IAA) through hardware-assisted codec.  

### Docker Image

The workload contains dockers image of clickhouse-iaa-base which include a fresh clickhouse server.  The Clickhouse server can be set up using either Kubernetes or Docker as a backend. Starting clickhouse server on IAA-enabled Host using Docker is as follows (if the IAA is not well set up in the host, it falls back to software codec)
```
docker run --rm --detach --privileged --network host clickhouse-iaa-base
```
There is another docker image clickhouse-iaa-unittest with simple Clickhouse command. Example to run the unittest is as follows, which mount the host dev directory to the container's dev directory for IAX to support the hardware-assisted codec:
```
docker run --rm --detach --privileged -v /dev:/dev --network host clickhouse-iaa-unittest
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

### Contact
  
- Stage1 Contact: [Chunrong Lai](mailto:chunrong.lai@intel.com)
- Stage2 Contact: [Jasper Zhu](mailto:jasper.zhu@intel.com)

### Index Info

- Name: `ClickHouse-iaa`
- Category: `DataServices`
- Platform: `SPR`
- keywords:  IAA
- Permission:
  
### See Also 

- [What is ClickHouse?](https://clickhouse.com/docs/en/intro)
- [Intel(R) In-Memory Analytics Accelerator Architecture Specification](https://cdrdv2-public.intel.com/721858/350295-iaa-specification.pdf)
- [Recipe of IAA deflate benchmark upon ClickHouse](https://github.com/intel-innersource/applications.databases.thirdparty.clickhouse-hero/blob/ck2112_iaa_dev/benchmark/iaadeflate/benchmark_recipe_ssb.md)

