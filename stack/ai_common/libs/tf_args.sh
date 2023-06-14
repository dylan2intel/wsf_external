#! /bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# tf common args
function tf_common_args() {

    # Use training, inference dataset
    if [[ "$PRECISION" =~ "fp32" ]]; then
        INPUT_PRECISION=fp32
        MODEL_DIR=/home/model/fp32_bert_squad.pb
    elif [[ "$PRECISION" =~ "int8" ]]; then
        INPUT_PRECISION=int8
        MODEL_DIR=/home/model/per_channel_opt_int8_bf16_bert.pb
    elif [[ "$PRECISION" =~ "bfloat16" ]]; then
        INPUT_PRECISION=bfloat16
        MODEL_DIR=/home/model/optimized_bf16_bert.pb
    else
        echo "Not support precision ${INPUT_PRECISION}"
        exit 1
    fi

    ARGS="--model-name=${TOPOLOGY} \
          --precision ${INPUT_PRECISION} \
          --mode=${FUNCTION} \
          --framework tensorflow"

    # Use real, dummy data
    if [ "$DATA_TYPE" == "real" ]; then
        ARGS+=" --data-location ${DATASET_DIR}"
    fi
    
    if [ "$FUNCTION" == "inference" ]; then
        ARGS+=" --batch-size ${BATCH_SIZE} \
                --in-graph ${MODEL_DIR}"
        if [ "$MODE" == "accuracy" ]; then
            ARGS+=" --accuracy-only"
        else
            ARGS+=" --benchmark-only \
                    --num-intra-threads ${CORES_PER_INSTANCE} \
                    --num-inter-threads 1"
        fi
        if [ "$TOPOLOGY" == "bert_large" ] || [ "$TOPOLOGY" == "resnet50v1_5" ]; then
            ARGS+=" --steps=${STEPS}"
        fi
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" -b ${BATCH_SIZE}"
        if [ "$TOPOLOGY" == "resnet50v1_5" ]; then
            ARGS+=" --train_epochs=1"
        fi
    else
        echo "Error, not support function ${FUNCTION}"
        exit 1
    fi

    if [ "$WEIGHT_SHARING" == "True" ] && [ "$MODE" == "latency" ]; then
        ARGS+=" WEIGHT_SHARING=True"
    fi
    echo $ARGS
}

# resnet50v1_5 tf args
function resnet50v1_5_tf_args() {

    # Use training, inference dataset
    if [ "$FUNCTION" == "training" ]; then
        DATASET_DIR=${TRAINING_DATASET_DIR}
    else
        DATASET_DIR=${INFERENCE_DATASET_DIR}
    fi

    # Use fp32, bf16, int8 model
    if [[ "$PRECISION" =~ "fp32" ]]; then
        MODEL_DIR=${FP32_MODEL_DIR}
        INPUT_PRECISION=fp32
    elif [[ "$PRECISION" =~ "int8" ]]; then
        MODEL_DIR=${INT8_MODEL_DIR}
        INPUT_PRECISION=int8
    elif [[ "$PRECISION" =~ "bfloat16" ]]; then
        MODEL_DIR=${BF16_MODEL_DIR}
        INPUT_PRECISION=bfloat16
    else
        echo "Not support precision ${INPUT_PRECISION}"
        exit 1
    fi

    # Common args
    ARGS="--model-name=${TOPOLOGY} \
        --precision ${INPUT_PRECISION} \
        --mode=${FUNCTION} \
        --framework tensorflow \
        --output-dir ${OUTPUT_DIR} \
        --batch-size ${BATCH_SIZE}"

    # Use real, dummy data
    if [ "$DATA_TYPE" == "real" ]; then
        ARGS+=" --data-location ${DATASET_DIR}"
    fi

    # Weight sharing
    if [ "$WEIGHT_SHARING" == "True" ]; then
        DATA_NUM_INTER_THREADS=-1
        INTER="--num-inter-threads -1 --weight-sharing"
    else
        DATA_NUM_INTER_THREADS=1
        INTER="--num-inter-threads 1"
    fi

    # Inference training args
    if [ "$FUNCTION" == "inference" ] ; then
        ARGS+=" --in-graph ${MODEL_DIR} \
                --disable-tcmalloc=True \
                --steps=${STEPS}"
        if [ "$MODE" == "throughput" ]; then
            ARGS+=" --data-num-intra-threads ${CORES_PER_INSTANCE} \
                    --data-num-inter-threads 1 \
                    --warmup_steps=${WARMUP_STEPS} \
                    --benchmark-only \
                    --num-intra-threads=${CORES_PER_INSTANCE} \
                    ${INTER}"
        elif [ "$MODE" == "latency" ]; then
            ARGS+=" --data-num-intra-threads ${CORES_PER_INSTANCE} \
                    --data-num-inter-threads ${DATA_NUM_INTER_THREADS} \
                    --warmup_steps=${WARMUP_STEPS} \
                    --benchmark-only \
                    --num-intra-threads=${CORES_PER_INSTANCE} \
                    ${INTER}"
        elif [ "$MODE" == "accuracy" ]; then
            ARGS+=" --socket-id 0 \
                    --accuracy-only"
        else
            echo "Error, not support mode $MODE"
            exit 1
        fi
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" --mpi_num_processes=${MPI} \
                --mpi_num_processes_per_socket=${NUM_MPI} \
                --checkpoint ${OUTPUT_DIR} \
                --num-intra-threads ${CORES_PER_INSTANCE} \
                --num-inter-threads 2 \
                --batch-size ${BATCH_SIZE} \
                --train_epochs=1 \
                --epochs_between_evals=1"
    else
        echo "Error, not support function ${FUNCTION}"
        exit 1
    fi
    echo $ARGS
}

# bertlarge tf args
function bertlarge_tf_args() {

    ARGS=$(tf_common_args)

    # Inference training args
    if [ "$FUNCTION" == "inference" ] ; then
        ARGS+=" --checkpoint ${CHECKPOINT_DIR} \
                --DEBIAN_FRONTEND=noninteractive \
                --init_checkpoint=model.ckpt-3649 \
                --infer-option=SQuAD \
                --max-seq-length=${MAX_SEQ_LENGTH} \
                --experimental-gelu=True"
    elif [ "$FUNCTION" == "training" ]; then
        ARGS+=" --num-train-steps=20 \
                --DEBIAN_FRONTEND=noninteractive \
                --train-option=Pretraining \
                --do-eval=False \
                --do-train=True \
                --profile=False \
                --learning-rate=4e-5 \
                --max-predictions=76 \
                --max-seq-length=${MAX_SEQ_LENGTH} \
                --warmup-steps=0 \
                --save-checkpoints_steps=1000 \
                --config-file=${DATASET_DIR}/bert_config.json \
                --init-checkpoint=${DATASET_DIR}/bert_model.ckpt \
                --input-file=${DATASET_DIR}/tf_records/part-00430-of-00500 \
                --experimental-gelu=True \
                --do-lower-case=False"
    else
        echo "Error, not support function ${FUNCTION}"
        exit 1
    fi
    echo $ARGS
}
