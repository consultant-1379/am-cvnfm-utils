#!/usr/bin/env bash

NAMESPACE="evnfm-metrics"
# next two should be changed to right location
CLUSTER="hart070-iccr"
ERICSSON_SUFFIX="ews.gic.ericsson.se"
RENDERER_NAME="renderer"
GRAFANA_NAME="grafana"
REPORTER_NAME="reporter"
PROMETHEUS_NAME="prometheus"
OPERATION=installation
GRAFANA_ADMIN_PASS=prom-operator
ICCR_NAME="iccr"

function info() {
  echo "[INFO] $1"
}

function createNamespace() {
  info "Checking if namespace $NAMESPACE exists"
  kubectl get namespaces | grep -w $NAMESPACE
  if [[ $? == 1 ]]; then
    info "Creating namespace $NAMESPACE"
    kubectl create namespace $NAMESPACE
  else
    info "Namespace $NAMESPACE already exists"
  fi
}

function writeKubePrometheusStackValueFile() {
DATA_SOURCE_URL="http://${PROMETHEUS_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}"

echo "namespaceOverride: ${NAMESPACE}

grafana:
  enabled: true
  namespaceOverride: ${NAMESPACE}
  defaultDashboardsTimezone: Europe/Kiev
  adminPassword: ${GRAFANA_ADMIN_PASS}
  env:
    GF_RENDERING_SERVER_URL: http://${RENDERER_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}/render
    GF_RENDERING_CALLBACK_URL: http://${GRAFANA_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}/
    GF_LOG_FILTERS: rendering:debug
    GF_SMTP_ENABLED: true
    GF_SMTP_HOST: "mail-vip.seli.gic.ericsson.se:25"
    GF_SMTP_SKIP_VERIFY: true
    GF_SMTP_FROM_ADDRESS: "grafana-${CLUSTER}@ericsson.com"
    GF_SMTP_FROM_NAME: "Grafana-${CLUSTER}"
  image:
    repository: armdockerhub.rnd.ericsson.se/grafana/grafana
    tag: 8.5.1
    sha: ""
    pullPolicy: IfNotPresent
  ingress:
    enabled: true
    ingressClassName: $ICCR_NAME
    hosts:
      - ${GRAFANA_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: \"600\"
  additionalDataSource:
    - name: Prometheus
      type: prometheus
      url: ${DATA_SOURCE_URL}
      access: proxy
  imageRenderer:
    enabled: false
    replicas: 1
    image:
      repository: armdockerhub.rnd.ericsson.se/grafana/grafana-image-renderer
      tag: latest
      sha: \"\"
      pullPolicy: Always
    env:
      HTTP_HOST: \"0.0.0.0\"
    serviceAccountName: \"\"
    securityContext: {}
    hostAliases: []
    priorityClassName: ''
    service:
      enabled: true
      portName: 'http'
      port: 8081
      targetPort: 8081
    grafanaSubPath: \"\"
    podPortName: http
    revisionHistoryLimit: 10
    networkPolicy:
      limitIngress: true
      limitEgress: false
    resources: {}

kube-state-metrics:
  namespaceOverride: ${NAMESPACE}

prometheus-node-exporter:
  namespaceOverride: ${NAMESPACE}
  service:
    port: 9090
    targetPort: 9090
  extraArgs:
    - --collector.processes

prometheus:
  prometheusSpec:
    enabled: true
    retention: \"28d\"
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: network-block
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi
    image:
      repository: prometheus/prometheus
      tag: v2.41.0
  resources: {}
  ingress:
    enabled: true
    ingressClassName: $ICCR_NAME
    hosts:
      - ${PROMETHEUS_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}" > prometheus.yaml
}

function kubePrometheusStack() {
  writeKubePrometheusStackValueFile
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm install prometheus prometheus-community/kube-prometheus-stack -f prometheus.yaml -n ${NAMESPACE} --debug
  rm prometheus.yaml
}

function writeReporterFile() {
  echo "apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ${REPORTER_NAME}
    group: ${NAMESPACE}-stats
  name: ${REPORTER_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${REPORTER_NAME}
  template:
    metadata:
      labels:
        app: ${REPORTER_NAME}
    spec:
      containers:
      - args:
        - -ip
        - reporter:reporter123@${GRAFANA_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}
        image: armdockerhub.rnd.ericsson.se/izakmarais/grafana-reporter:2.3.1
        name: ${REPORTER_NAME}
        ports:
        - containerPort: 8686
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: ${REPORTER_NAME}-svc
    group: ${NAMESPACE}-stats
  name: ${REPORTER_NAME}-svc
spec:
  ports:
  - name: \"8686\"
    port: 8686
    targetPort: 8686
  selector:
    app: ${REPORTER_NAME}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  labels:
    group: ${NAMESPACE}-stats
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: \"600\"
  name: ${REPORTER_NAME}-ingress
spec:
  ingressClassName: $ICCR_NAME
  rules:
  - host: ${REPORTER_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${REPORTER_NAME}-svc
            port:
              number: 8686
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  labels:
    group: ${NAMESPACE}-stats
  name: ${REPORTER_NAME}-external-traffic
spec:
  podSelector:
    matchLabels:
      app: ${REPORTER_NAME}
  ingress:
  - from: []" > reporter.yaml
}

function createReporter() {
  info "Create user reporter"
  sleep 30
  curl -X POST http://admin:${GRAFANA_ADMIN_PASS}@${GRAFANA_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}/api/admin/users -H "Accept: application/json" -H "Content-Type: application/json" -d '{"login":"reporter","password":"reporter123"}'
  info "Apply renderer file"
  writeReporterFile
  kubectl apply -f reporter.yaml -n ${NAMESPACE}
  rm reporter.yaml
}

function writeRendererFile() {
  echo "apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${RENDERER_NAME}
  labels:
    app: ${RENDERER_NAME}
    group: ${NAMESPACE}-stats
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${RENDERER_NAME}
  template:
    metadata:
      labels:
        app: ${RENDERER_NAME}
    spec:
      containers:
      - image: armdockerhub.rnd.ericsson.se/grafana/grafana-image-renderer:3.4.2
        name: ${RENDERER_NAME}
        ports:
        - containerPort: 8081
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: ${RENDERER_NAME}-svc
  labels:
    app: ${RENDERER_NAME}
    group: ${NAMESPACE}-stats
spec:
  ports:
  - name: \"8081\"
    port: 8081
    targetPort: 8081
  selector:
    app: ${RENDERER_NAME}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${RENDERER_NAME}-ingress
  labels:
    group: ${NAMESPACE}-stats
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: \"600\"
spec:
  ingressClassName: $ICCR_NAME
  rules:
  - host: ${RENDERER_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${RENDERER_NAME}-svc
            port:
              number: 8081
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: ${RENDERER_NAME}-external-traffic
  labels:
    group: ${NAMESPACE}-stats
spec:
  podSelector:
    matchLabels:
      app: ${RENDERER_NAME}
  ingress:
  - from: []" > renderer.yaml
}

function createRenderer() {
  writeRendererFile
  kubectl apply -f renderer.yaml -n ${NAMESPACE}
  rm renderer.yaml
}

function showHelp() {
  echo "
  ##############################################################################################################
  #                                                                                                            #
  #        --d - delete Grafana and modules; if this flag                                                      #
  #             is enabled, all other, except --n, will be ignored                                             #
  #        --n - namespace where to install/uninstall Grafana                                                  #
  #                                                                                                            #
  ##############################################################################################################
  "
}

function deleteDeployment() {
  echo "Deleting prometheus release in namespace: ${NAMESPACE}"
  helm uninstall ${PROMETHEUS_NAME} -n ${NAMESPACE}
  kubectl delete all --all -n ${NAMESPACE}
  echo "Deleting prometheus CRDs"
  for each in $(kubectl get crd -o name | grep monitoring.coreos); do
    kubectl delete $each;
  done
  echo "Checking left resources in namespace: ${NAMESPACE}"
  kubectl get all -n ${NAMESPACE}
  helm repo remove prometheus-community
  echo "Deleting namespace: ${NAMESPACE}"
  kubectl delete ns ${NAMESPACE}
  exit 1
}

function links_and_creds() {
  echo "
  ##############################################################################################################

  Grafana:
        link: http://${GRAFANA_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}
        login: admin
        password: ${GRAFANA_ADMIN_PASS}
  Prometheus:
        type: ${PROMETHEUS}
        link: http://${PROMETHEUS_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}
  Reporter:
          link: http://${REPORTER_NAME}.${CLUSTER}.${ERICSSON_SUFFIX}

  ##############################################################################################################
  "
}

if ! TEMP=$(getopt -o . -l *,d,n:,h -n 'javawrap' -- "$@"); then
  showHelp
  exit 1
fi

eval set -- "$TEMP"
while true; do
  case "$1" in
  --d)
    OPERATION=deletion
    shift 1
    ;;
  --n)
    NAMESPACE=$2
    shift 2
    ;;
  -h | --help)
    showHelp
    exit 1
    ;;
  *) break ;;
  esac
done

if [ $OPERATION == deletion ]; then
  deleteDeployment
fi

createNamespace
kubePrometheusStack
createRenderer
createReporter
links_and_creds
