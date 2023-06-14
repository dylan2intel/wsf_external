#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: rocksdb-iaa
spec:
  template:
    spec:
      containers:
      - name: rocksdb-iaa
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `TYPE'
          value: "TYPE"
        - name: `KEY_SIZE'
          value: "KEY_SIZE"
        - name: `VALUE_SIZE'
          value: "VALUE_SIZE"
        - name: `BLOCK_SIZE'
          value: "BLOCK_SIZE"
        - name: `THREADS_NUM'
          value: "THREADS_NUM"
        - name: `NUMA_OPTIONS'
          value: "NUMA_OPTIONS"
        securityContext:
          privileged: true
        volumeMounts:
        - mountPath: /dev
          name: dev
        - mountPath: /var/tmp
          name: tmp
        - mountPath: /sys
          name: sys
        - mountPath: /lib/modules
          name: modules
      restartPolicy: Never
      volumes:
      - name: dev
        hostPath:
          path: /dev
          type: Directory
      - name: tmp
        hostPath:
          path: /var/tmp
          type: Directory
      - name: sys
        hostPath:
          path: /sys
          type: Directory
      - name: modules
        hostPath:
          path: /lib/modules
          type: Directory
  backoffLimit: 4