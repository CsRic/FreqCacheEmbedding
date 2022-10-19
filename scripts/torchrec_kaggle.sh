#!/bin/bash
set -x

export DATAPATH=/data/scratch/RecSys/criteo_kaggle_data/
# export DATAPATH=/data/criteo_kaggle_data/

set_n_least_used_CUDA_VISIBLE_DEVICES() {
    local n=${1:-"9999"}
    echo "GPU Memory Usage:"
    local FIRST_N_GPU_IDS=$(nvidia-smi --query-gpu=memory.used --format=csv \
        | tail -n +2 \
        | nl -v 0 \
        | tee /dev/tty \
        | sort -g -k 2 \
        | awk '{print $1}' \
        | head -n $n)
    export CUDA_VISIBLE_DEVICES=$(echo $FIRST_N_GPU_IDS | sed 's/ /,/g')
    echo "Now CUDA_VISIBLE_DEVICES is set to:"
    echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
}

export GPUNUM=1

for EMB_DIM in 128 #64 96
do
for PREFETCH_NUM in 4 #1 8 16 32
do
for GPUNUM in 4
do
for KERNELTYPE in "colossalai" # "fused" # "colossalai"
do
for BATCHSIZE in 4096 #16384 8192 4096 2048 1024 512     
do
for SHARDTYPE in "row" # "column" "row" "tablecolumn" "tablerow" "table"
# for SHARDTYPE in "tablerow" 
do
# For TorchRec baseline
set_n_least_used_CUDA_VISIBLE_DEVICES ${GPUNUM}
rm -rf ./tensorboard_log/torchrec_kaggle/w${GPUNUM}_${BATCHSIZE}_${SHARDTYPE}
# env CUDA_LAUNCH_BLOCKING=1 
# timeout -s SIGKILL 30m 
LOG_DIR=./logs/${KERNELTYPE}_${SHARDTYPE}_logs
mkdir -p ${LOG_DIR}

torchx run -s local_cwd -cfg log_dir=log/torchrec_kaggle/${PLAN} dist.ddp -j 1x${GPUNUM} --script baselines/dlrm_main.py -- \
    --in_memory_binary_criteo_path ${DATAPATH} --kaggle --embedding_dim ${EMB_DIM} --pin_memory --cache_ratio 0.10 \
    --over_arch_layer_sizes "1024,1024,512,256,1" --dense_arch_layer_sizes "512,256,${EMB_DIM}" --shuffle_batches --eval_acc \
    --learning_rate 1. --batch_size ${BATCHSIZE} --profile_dir "" --shard_type ${SHARDTYPE} --kernel_type ${KERNELTYPE} --prefetch_num ${PREFETCH_NUM} ${EVAL_ACC_FLAG} 2>&1 | tee ./${LOG_DIR}/torchrec_${PLAN}.txt
done
done
done
done
done
done
# exit(0)
# torchx run -s local_cwd -cfg log_dir=log/torchrec_kaggle/w2_16k dist.ddp -j 1x2 --script baselines/dlrm_main.py -- \
#     --in_memory_binary_criteo_path /data/criteo_kaggle_data --kaggle --embedding_dim 128 --pin_memory \
#     --over_arch_layer_sizes "1024,1024,512,256,1" --dense_arch_layer_sizes "512,256,128" --shuffle_batches \
#     --learning_rate 1. --batch_size 8192  --profile_dir "tensorboard_log/torchrec_kaggle/w2_16k"

# torchx run -s local_cwd -cfg log_dir=log/torchrec_kaggle/w4_16k dist.ddp -j 1x4 --script baselines/dlrm_main.py -- \
#     --in_memory_binary_criteo_path /data/criteo_kaggle_data --kaggle --embedding_dim 128 --pin_memory \
#     --over_arch_layer_sizes "1024,1024,512,256,1" --dense_arch_layer_sizes "512,256,128" --shuffle_batches \
#     --learning_rate 1. --batch_size 4096  --profile_dir "tensorboard_log/torchrec_kaggle/w4_16k"

# torchx run -s local_cwd -cfg log_dir=log/torchrec_kaggle/w8_16k dist.ddp -j 1x8 --script baselines/dlrm_main.py -- \
#     --in_memory_binary_criteo_path /data/criteo_kaggle_data --kaggle --embedding_dim 128 --pin_memory \
#     --over_arch_layer_sizes "1024,1024,512,256,1" --dense_arch_layer_sizes "512,256,128" --shuffle_batches \
#     --learning_rate 1. --batch_size 2048  --profile_dir "tensorboard_log/torchrec_kaggle/w8_16k"
