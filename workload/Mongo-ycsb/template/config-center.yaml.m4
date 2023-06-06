define(`configCenter', `dnl
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: config-center
  name: config-center
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-center
  template:
    metadata:
      labels:
        app: config-center
    spec:
      containers:
      - image: IMAGENAME(Dockerfile.2.ycsb)
        imagePullPolicy: IMAGEPOLICY(Always)
        command: ["/bin/bash", "-c","(exec redis-server --protected-mode no & ) && sleep infinity"]
        name: config-center
        resources: {}
      dnsPolicy: ClusterFirst
      restartPolicy: Always
ifelse(RUN_SINGLE_NODE,false,`dnl
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: name
                operator: In
                values:
                - MONGODB-SERVER
            topologyKey: kubernetes.io/hostname              
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: name
                  operator: In
                  values:
                  - MONGODB-CLIENT
              topologyKey: kubernetes.io/hostname
        node_Affinity(`VM-GROUP',`client')dnl
',)
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: config-center
  name: config-center
spec:
  ports:
  - port: defn(`CONFIG_CENTER_PORT')
    protocol: TCP
    targetPort: 6379
  selector:
    app: config-center
  type: ClusterIP
')