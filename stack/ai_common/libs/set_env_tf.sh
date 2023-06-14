#! /bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/info.sh

echo "============ Setting TensorFlow environment variable ============"

tf_ver=$(python -c "import tensorflow; print(tensorflow.__version__)")
echo "TensorFlow_Version: ${tf_ver}"

# # Set tf onednn env variable
if [[ "$tf_ver" =~ "2." ]]; then
    tf_enable_onednn="TF_ENABLE_ONEDNN_OPTS=1 TF_ENABLE_MKL_NATIVE_FORMAT=1"
    echo "Set ENV ${tf_enable_onednn}"
    export ${tf_enable_onednn}
elif [[ "$tf_ver" =~ "1." ]]; then
    tf_disenable_onednn="TF_ENABLE_ONEDNN_OPTS=0 TF_ENABLE_MKL_NATIVE_FORMAT=0"
    echo "Set ENV ${tf_disenable_onednn}"
    export ${tf_disenable_onednn}
fi

# Set tf customer env variable
if [ -n "$CUSTOMER_ENV" ]; then
    export $CUSTOMER_ENV
fi

# Set tf ISA env variable
function set_tf_ISA_env {
    if [[ "$PRECISION" =~ "amx" ]]; then
        tf_ISA_env_cmd="ONEDNN_MAX_CPU_ISA=AVX512_CORE_AMX"
        echo "Set ENV ${tf_ISA_env_cmd}"
        export ${tf_ISA_env_cmd}
    elif [[ "$PRECISION" =~ "avx" ]]; then
        tf_ISA_env_cmd="ONEDNN_MAX_CPU_ISA=AVX512_CORE_BF16"
        echo "Set ENV ${tf_ISA_env_cmd}"
        export ${tf_ISA_env_cmd}
    else
        echo "Not support precision ${PRECISION}"
        exit 1
    fi
    if [ "$PRECISION" == "amx_bfloat32" ]; then
        echo "Set ENV ONEDNN_DEFAULT_FPMATH_MODE=BF16"
        export "ONEDNN_DEFAULT_FPMATH_MODE=BF16"
    fi
}

# Set tf OMP env variable
function set_tf_OMP_env {
    if [ "$CORES_PER_INSTANCE" != "-1" ]; then
        tf_OMP_env_cmd="OMP_NUM_THREADS=${CORES_PER_INSTANCE}"
        echo "Set ENV ${tf_OMP_env_cmd}"
        export ${tf_OMP_env_cmd}
    else
        if [ "$WEIGHT_SHARING" == "Ture" ] && [ "$MODE" == "latency" ]; then
            tf_KMP_env_cmd="KMP_BLOCKTIME=1"
            tf_OMP_env_cmd="OMP_NUM_THREADS=4"
            echo "Set ENV ${tf_KMP_env_cmd}"
            echo "Set ENV ${tf_OMP_env_cmd}"
            export "${tf_KMP_env_cmd}, ${tf_OMP_env_cmd}"
        else
            tf_OMP_env_cmd="OMP_NUM_THREADS=${CORES_PER_INSTANCE}"
            echo "Set ENV ${tf_OMP_env_cmd}"
            export ${tf_OMP_env_cmd}
        fi
    fi
    if [ "$THREADS_PER_CORE" == "1" ]; then
        echo "Set ENV KMP_AFFINITY=granularity=fine,verbose,compact"
        export "KMP_AFFINITY=granularity=fine,verbose,compact"
    else
        echo "Set ENV KMP_AFFINITY=granularity=fine,verbose,compact,1,0"
        export "KMP_AFFINITY=granularity=fine,verbose,compact,1,0"
    fi
}

# Set tf script env variable
function set_tfscript_env {
    echo "Set ENV NOINSTALL=True TF_ENABLE_MKL_NATIVE_FORMAT=1"
    export "NOINSTALL=True TF_ENABLE_MKL_NATIVE_FORMAT=1"
}

# Set case env variable (resnet50_tf)
function set_tf_case_env {
    if [ "$WEIGHT_SHARING" == "True" ]; then
        echo "Set ENV TF_ENABLE_MKL_NATIVE_FORMAT=0"
        export "TF_ENABLE_MKL_NATIVE_FORMAT=0"
    fi
    if [ "$MODE" == "latency" ]; then
        echo "Set ENV TF_USE_SYSTEM_ALLOCATOR=1"
        export "TF_USE_SYSTEM_ALLOCATOR=1"
    fi
    if [ "$FUNCTION" == "training" ]; then
        echo "Set ENV TF_ENABLE_MKL_NATIVE_FORMAT=1"
        export "TF_ENABLE_MKL_NATIVE_FORMAT=1"
    fi
}

# Set tf verbose env variable
function set_tf_verbose_env {
    if [ "$ONEDNN_VERBOSE" == "True" ]; then
        tf_verbose_value="DNNL_VERBOSE=1"
    else
        tf_verbose_value="DNNL_VERBOSE=0"
    fi
    echo "Set ENV ${tf_verbose_value}"
    export ${tf_verbose_value}
}

# Set all tf env variable
function set_tf_env {
    set_tf_ISA_env
    set_tf_OMP_env
    set_tfscript_env
}
