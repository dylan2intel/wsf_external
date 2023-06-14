#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)
---

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: clickhouse-iaa-server
  name: clickhouse-iaa-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clickhouse-iaa-server
  template:
    metadata:
      labels:
        app: clickhouse-iaa-server
        deployPolicy: server
    spec:
      containers:
      - name: clickhouse-iaa-server
        image: IMAGENAME(Dockerfile.1.iaaserver)
        imagePullPolicy: Always
        command: ["/bin/bash"]
        args: ["-c", "clickhouse server --config-file=/etc/clickhouse-server/config.xml"]
        ports:
        - containerPort: 9000
        - containerPort: 8123
        env:
        - name: `WORKLOAD'
          value: "defn(`WORKLOAD')"
        securityContext:
          privileged: true

---

apiVersion: v1
kind: Service
metadata:
  labels:
    app: clickhouse-iaa-server
  name: clickhouse-iaa
spec:
  selector:
    app: clickhouse-iaa-server
  ports:
  - name: database
    protocol: TCP
    port: 9000
    targetPort: 9000
  - name: web-interface
    protocol: TCP
    port: 8123
    targetPort: 8123

---

apiVersion: batch/v1
kind: Job
metadata:
  name: clickhouse-iaa-benchmark
  labels:
    app: clickhouse-iaa-benchmark
spec:
  template:
    metadata:
      labels:
        app: clickhouse-iaa-benchmark
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - clickhouse-iaa-server
            topologyKey: "kubernetes.io/hostname"
      dnsPolicy: ClusterFirstWithHostNet
      initContainers:
      - name: wait-for-database-service
        image: busybox:1.28
        command: ["sh", "-c", "until nc -z -w5 clickhouse 8123; do echo waiting for Clickhouse Server; sleep 2; done"]
      containers:
      - name: clickhouse-iaa-benchmark
        image: IMAGENAME(Dockerfile.2.iaabenchmark)
        imagePullPolicy: Always
        env:
        - name: `WORKLOAD'
          value: "defn(`WORKLOAD')"
        - name: `BACKEND'
          value: "defn(`BACKEND')"
        - name: `TESTCASE'
          value: "defn(`TESTCASE')"
        securityContext:
          privileged: true
      restartPolicy: Never
  backoffLimit: 5
