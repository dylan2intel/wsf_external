### Introduction

Stack image for [LAMMPS](https://www.lammps.org/) (Large-scale Atomic/Molecular Massively Parallel Simulator) based on [Intel oneAPI HPC Toolkit](https://hub.docker.com/r/intel/oneapi-hpckit) (ver. [2023.0.0-devel-ubuntu22.04](https://hub.docker.com/layers/intel/oneapi-hpckit/2023.0.0-devel-ubuntu22.04/images/sha256-b44681ad4c02c66a1b6607ca809f44c4b3cf5a8251d113979cbd24023f1fe50e?context=explore)) and [LAMMPS package](https://github.com/lammps/lammps/) (ver. [stable_23Jun2022_update4](https://github.com/lammps/lammps/releases/tag/stable_23Jun2022_update4)).

This is the base stack for LAMMPS workloads. The Dockerfile builds the `oneapi_prune`, `hpc_lammps_serial_src`, `hpc_lammps_intel_src` images.

### Building images
#### Automated image building
Execute `make` inside the folder to build all of the images.

#### Manual image building
1. Set `RELEASE` variable to a single value, e.g. `RELEASE=latest`
2. Build oneapi-hpckit
    `docker build -t oneapi-hpckit-stack:${RELEASE} -f Dockerfile.9.oneapi-hpckit .`
3. Build intel-lammps
    `docker build -t intel-lammps:${RELEASE} -f Dockerfile.8.hpc_lammps_intel_src .`

#### Automated test execution
Execute `ctest -V` to run default unittest case. Check [docummentation](../../doc/user-guide/executing-workload/ctest.md) for more options.

### System Requirements
Intel® AVX-512 support.

### BOM
| Component | Version | Source |
| --- | --- | --- |
| Intel oneAPI HPC Toolkit | 2023.0.0-devel-ubuntu22.04 | [DockerHub](https://hub.docker.com/layers/intel/oneapi-hpckit/2023.0.0-devel-ubuntu22.04/images/sha256-b44681ad4c02c66a1b6607ca809f44c4b3cf5a8251d113979cbd24023f1fe50e?context=explore) |
| LAMMPS | 23Jun2022_update4 | [GitHub repository](https://github.com/lammps/lammps/releases/tag/stable_23Jun2022_update4) |
| Ubuntu base OS | 22.04 | [DockerHub](https://hub.docker.com/layers/library/ubuntu/22.04/images/sha256-c985bc3f77946b8e92c9a3648c6f31751a7dd972e06604785e47303f4ad47c4c?context=explore) |
| numactl | 2.0.14-3ubuntu2 | apt repository |
| build-essential | 12.9ubuntu3 | apt repository |
| wget | 1.21.2-2ubuntu1 | apt repository |

### Index Info
- Name: `LAMMPS`
- Category: `HPC`
- Platform: `ICX`, `SPR`
- Keywords:
