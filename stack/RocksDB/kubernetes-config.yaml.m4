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
    metadata:
      labels:
        deployPolicy: standalone
    spec:
      hostNetwork: true
      dnsPolicy: Default 
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile.1.rocksdb.iaa.unittest)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `TYPE'
          value: "TYPE"
        - name: `METHOD'
          value: "METHOD"
        volumeMounts:
        - mountPath: /dev
          name: dev
      restartPolicy: Never
      volumes:
      - name: dev
        hostPath:
          path: /dev
          type: Directory
  backoffLimit: 4
