#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: benchmark
spec:
  template:
    spec:
      containers:
      - name: benchmark
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        volumeMounts:
        - mountPath: /dev/shm
          name: dshm
        env:
        - name: N_SIZE
          value: "defn(`K_N_SIZE')"
        - name: ASM
          value: "defn(`K_ASM')"
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: "defn(`SHM_SIZE')Gi"

      restartPolicy: Never
  backoffLimit: 4
