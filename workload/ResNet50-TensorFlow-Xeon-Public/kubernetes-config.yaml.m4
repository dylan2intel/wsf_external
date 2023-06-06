include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: resnet50v15-tensorflow-xeon-public-benchmark
spec:
  template:
    spec:
      containers:
      - name: resnet50v15-tensorflow-xeon-public-benchmark
        image: IMAGENAME(Dockerfile.1.intel-public-inference)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `WORKLOAD'
          value: "defn(`K_WORKLOAD')"
        - name: `PLATFORM'
          value: "defn(`K_PLATFORM')"
        - name: MODE
          value: "defn(`K_MODE')"
        - name: TOPOLOGY
          value: "defn(`K_TOPOLOGY')"
        - name: FUNCTION
          value: "defn(`K_FUNCTION')"
        - name: PRECISION
          value: "defn(`K_PRECISION')"
        - name: BATCH_SIZE
          value: "defn(`K_BATCH_SIZE')"
        - name: STEPS
          value: "defn(`K_STEPS')"
        - name: DATA_TYPE
          value: "defn(`K_DATA_TYPE')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        - name: WEIGHT_SHARING
          value: "defn(`K_WEIGHT_SHARING')"
        - name: CASE_TYPE
          value: "defn(`K_CASE_TYPE')"
        - name: ONEDNN_VERBOSE
          value: "defn(`K_ONEDNN_VERBOSE')"
        - name: MPI
          value: "defn(`K_MPI')"
        - name: NUM_MPI
          value: "defn(`K_NUM_MPI')"
        - name: CUSTOMER_ENV
          value: "defn(`K_CUSTOMER_ENV')"
        - name: VERBOSE
          value: "defn(`K_VERBOSE')"
        securityContext:
          privileged: true  
      NODEAFFINITY(preferred,HAS-SETUP-BKC-AI,"yes")
      restartPolicy: Never
