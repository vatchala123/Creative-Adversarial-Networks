#!/bin/bash
# Copyright 2017 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
#
# This script performs the following operations:
# 1. Downloads the wikiart dataset
# 2. Fine-tunes an Inception Resnet V2 model on the wikiart training set.
# 3. Evaluates the model on the wikiart validation set.
#
# Usage:
# cd slim
# ./slim/scripts/finetune_inception_resnet_v2_on_wikiart.sh
export CUDA_VISIBLE_DEVICES=1
set -e

# Where the pre-trained Inception Resnet V2 checkpoint is saved to.
PRETRAINED_CHECKPOINT_DIR=logs/pretrained
# Where the pre-trained Inception Resnet V2 checkpoint is saved to.
MODEL_NAME=inception_resnet_v2

# Where the training (fine-tuned) checkpoint and logs will be saved to.
TRAIN_DIR=logs/wikiart/${MODEL_NAME}

# Where the dataset is saved to.
INPUT_DATASET_DIR=/data/wikiart/
DATASET_DIR=/data/wikiart-records

# Download the pre-trained checkpoint.
if [ ! -d "$PRETRAINED_CHECKPOINT_DIR" ]; then
  mkdir -p ${PRETRAINED_CHECKPOINT_DIR}
fi
if [ ! -f ${PRETRAINED_CHECKPOINT_DIR}/${MODEL_NAME}.ckpt ]; then
  wget http://download.tensorflow.org/models/inception_resnet_v2_2016_08_30.tar.gz
  tar -xvf inception_resnet_v2_2016_08_30.tar.gz
  mv inception_resnet_v2_2016_08_30.ckpt ${PRETRAINED_CHECKPOINT_DIR}/${MODEL_NAME}.ckpt
  rm inception_resnet_v2_2016_08_30.tar.gz
fi

# # Download the dataset
python download_and_convert_data.py \
  --dataset_name=wikiart \
  --dataset_dir=${DATASET_DIR}
  --input_dataset_dir=${INPUT_DATASET_DIR}

# @philkuz I use this to create a nice initialization - haven't tried random
# TODO try out if your'e curious to see whether random initialization of last
# layer makes sense in this case.
# Fine-tune only the last layer for 1000 steps.
python3 train_image_classifier.py \
  --train_dir=${TRAIN_DIR} \
  --dataset_name=wikiart \
  --dataset_split_name=train \
  --dataset_dir=${DATASET_DIR} \
  --model_name=${MODEL_NAME} \
  --checkpoint_path=${PRETRAINED_CHECKPOINT_DIR}/${MODEL_NAME}.ckpt \
  --checkpoint_exclude_scopes=InceptionResnetV2/Logits,InceptionResnetV2/AuxLogits \
  --trainable_scopes=InceptionResnetV2/Logits,InceptionResnetV2/AuxLogits \
  --max_number_of_steps=10000 \
  --batch_size=32 \
  --learning_rate=0.01 \
  --learning_rate_decay_type=fixed \
  --save_interval_secs=300 \
  --save_summaries_secs=60 \
  --log_every_n_steps=200 \
  --optimizer=rmsprop \
  --train_image_size=256 \
  --weight_decay=0.00004

# Run evaluation.
python3 eval_image_classifier.py \
  --checkpoint_path=${TRAIN_DIR} \
  --eval_dir=${TRAIN_DIR} \
  --dataset_name=wikiart \
  --dataset_split_name=validation \
  --dataset_dir=${DATASET_DIR} \
  --model_name=${MODEL_NAME} \
  --eval_image_size=256

# Fine-tune all the new layers for 500 steps.
NUM_EPOCHS=100
BATCH_SIZE=16
EXPERIMENT_NAME=inception_resnet_v2
LR=0.0001 \

TRAIN_DIR=logs/wikiart/inception_resnet_v2/experiments/${EXPERIMENT_NAME}/bs=${BATCH_SIZE},lr=${LR},epochs=${NUM_EPOCHS}/

python3 train_image_classifier.py \
  --train_dir=${TRAIN_DIR}/all \
  --dataset_name=wikiart \
  --dataset_split_name=train \
  --dataset_dir=${DATASET_DIR} \
  --model_name=${MODEL_NAME} \
  --checkpoint_path=${TRAIN_DIR} \
  --batch_size=${BATCH_SIZE} \
  --learning_rate=${LR} \
  --learning_rate_decay_type=fixed \
  --save_interval_secs=300 \
  --save_summaries_secs=60 \
  --num_epochs_per_decay=1 \
  --log_every_n_steps=200 \
  --optimizer=adam \
  --weight_decay=0.00004 \
  --experiment_name=${EXPERIMENT_NAME} \
  --num_epochs=${NUM_EPOCHS} \
  --train_image_size=256 \
  --continue_training False \
  # --experiment_numbering # TODO flag to flip on experiment numbering independent of experiement name arg existing
# # TODO catch the naming convention

# Run evaluation.
EVAL_DIR=logs/wikiart/inception_resnet_v2/all/bs=${BATCH_SIZE},lr=${LR},epochs=${NUM_EPOCHS}/${EXPERIMENT_NAME}
python3 eval_image_classifier.py \
  --checkpoint_path=${EVAL_DIR} \
  --eval_dir=${EVAL_DIR} \
  --dataset_name=wikiart \
  --dataset_split_name=validation \
  --dataset_dir=${DATASET_DIR} \
  --model_name=${MODEL_NAME} \
  --eval_image_size=256 \
