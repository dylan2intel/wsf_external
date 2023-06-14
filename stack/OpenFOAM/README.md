### Introduction

OpenFOAM is an open source software package for computational fluid dynamics (CFD). This workload runs
the "Motorbike" benchmark included with the openfoam library. Motorbike simulates a wind-tunnel test by
analyzing airflow over a 3d model of a motorcycle. The workload pre-processes the 3d model to generate
model mesh data that is fed into OpenFOAM's `simpleFoam` solver. The amount of detail of the mesh, and
consequently, its size, is determined by how the model is divided into slices in the x/y/z dimensions.
More slices corresponds to a higher resolution mesh and longer solve time.

This is the base stack for OpenFOAM workloads. The Dockerfile builds the `openfoam10-base-avx3` and `openfoam10-base-avx3-unitttest` images.

### Terms of Use
Please read and accept the [terms of use](https://www.intel.com/content/www/us/en/legal/terms-of-use.html) before running this workload.
*IF YOU DO NOT AGREE TO THE TERMS, DO NOT ACCESS OR RUN THIS WORKLOAD OR ANY MATERIALS FROM IT.*

### Building images
#### Automated image building
Execute `make` inside the folder to build all of the images.

#### Manual image building
1. Set `RELEASE` variable to a single value, e.g. `RELEASE=latest`
2. Build openfoam avx3 image.
    `docker build -t openfoam10-base-avx3:${RELEASE} -f Dockerfile.2.avx3 .`
3. (Optional) For testing, build unittest image.
    `docker build -t openfoam10-base-avx3-unittest:${RELEASE} -f Dockerfile.1.avx3.unittest .`

### Unit Test

Use the following commands to show the list of test cases:
```
cd build
cmake ..
cd stack/OpenFOAM
./ctest.sh -N

or
./ctest.sh -V
(run all test cases)

Test cases:
  Test #1: test_openfoam10_base_version_check
```
The unit test will pass if all installed versions in software stack is consistent with the expectation,
otherwise, unit test will fail.

#### Automated test execution
Execute `ctest -V` to run default unittest case. Check [docummentation](../../doc/user-guide/executing-workload/ctest.md) for more options.

#### Manual test execution
To execute default test case, run `docker run --rm -it --shm-size=4gb openfoam10-base-avx3-unittest`. Optionally, change environment variables using `-e` flag to overwrite default values, as mentioned in the sections above.

### System Requirements
Intel® AVX-512 support.

### Index Info
- Name: `LAMMPS`
- Category: `HPC`
- Platform: `ICX`, `SPR`
- Keywords:
