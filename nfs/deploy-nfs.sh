#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")
SIGNUM=$(whoami) # do not change this
NAMESPACE="${SIGNUM}-nfs-ns" # change this for alternative deployment e.g. "$SIGNUM"-<text>-ns
IMAGE_URL="armdocker.rnd.ericsson.se/proj-am/custom/alpine-nfs"
PVC_SIZE="2Gi"
FORCE="false"
BUILD="false"
DEPLOY="false"
SVC_PORT=2049
LB_IP=''

PVC_CONFIG=$(cat <<-EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  storageClassName: network-block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${PVC_SIZE}
EOF
)

DEPLOYMENT_CONFIG=$(cat <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-server
spec:
  replicas: 1
  selector:
    matchLabels:
      role: nfs
  template:
    metadata:
      name: nfs-server
      labels:
        role: nfs
    spec:
      volumes:
        - name: nfs-pv-storage
          persistentVolumeClaim:
            claimName: nfs-pvc
      securityContext:
        fsGroup: 1000
      containers:
        - name: nfs-server-container
          image: ${IMAGE_URL}
          ports:
          - containerPort: ${SVC_PORT}
          securityContext:
            privileged: true
          env:
            - name: SHARED_DIRECTORY
              value: "/exports"
          volumeMounts:
            - mountPath: "/exports"
              name: nfs-pv-storage
EOF
)

SVC_NP_CONFIG=$(cat <<-EOF
apiVersion: v1
kind: Service
metadata:
  name: nfs-nodeport
spec:
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  selector:
    role: nfs
  ports:
    - name: tcp-${SVC_PORT}
      targetPort: ${SVC_PORT}
      port: ${SVC_PORT}
      protocol: TCP
  type: NodePort
EOF
)

function render_lb_config() {
    SVC_LB_CONFIG=$(cat <<-EOF
    apiVersion: v1
    kind: Service
    metadata:
        name: nfs-lb
    spec:
        type: LoadBalancer
        selector:
          role: nfs
        ports:
        - name: tcp-${SVC_PORT}
          targetPort: ${SVC_PORT}
          port: ${SVC_PORT}
          protocol: TCP
        loadBalancerIP: ${LB_IP}
        allocateLoadBalancerNodePorts: false
EOF
)
}

function info() {
    echo -e "[\033[0;34mINFO\033[0m] $1"
}

function warn() {
    echo -e "[\033[0;33mWARN\033[0m] $1"
}

function debug() {
    echo -e "[\033[1;35mDEBG\033[0m] $1"
}

function docker_build() {
    info "building the docker image"
    docker build --tag "${IMAGE_URL}" .
    docker push "${IMAGE_URL}:latest"
}

function create_ns() {
    info "Create ns"
    if kubectl get ns ${NAMESPACE} 2>&1>/dev/null; then
        if [ ${FORCE} != "true" ]; then
            warn "${NAMESPACE} ns already exists, exiting"
            exit 1
        else
            info "${NAMESPACE} ns exists, recreating..."
            kubectl delete ns ${NAMESPACE} 2>&1>/dev/null
            kubectl create ns ${NAMESPACE} 2>&1>/dev/null
        fi
    else
        kubectl create ns ${NAMESPACE}
    fi
}

function create_pvc() {
    info "Create pvc"
    #sed -i -E "s/storage:(.*)/storage: ${PVC_SIZE}/g" ${SCRIPT_PATH}/pvc.yaml
    #kubectl -n ${NAMESPACE} apply -f ${SCRIPT_PATH}/pvc.yaml
    echo "${PVC_CONFIG}" | kubectl apply -n ${NAMESPACE} -f -
}

function create_deployment() {
    info "Create deployment"
    #sed -i -E 's/image:(.*)/image: '${IMAGE_URL//\//\\/}'/g' ${SCRIPT_PATH}/deployment.yaml
    #kubectl -n ${NAMESPACE} apply -f ${SCRIPT_PATH}/deployment.yaml
    echo "${DEPLOYMENT_CONFIG}" | kubectl apply -n ${NAMESPACE} -f -
}

function create_svc() {
    info "Create service"
    if [ -z ${LB_IP} ]; then
        info "LoadBalancer IP is not provided, deploying nodeport service"
        #kubectl -n ${NAMESPACE} apply -f ${SCRIPT_PATH}/service.yaml
        echo "${SVC_NP_CONFIG}" | kubectl apply -n ${NAMESPACE} -f -
    else
        info "LoadBalancer IP provided, deploying LB service"
        #sed -i -E 's/loadBalancerIP:(.*)/loadBalancerIP: '${IMAGE_URL//\//\\/}'/g' ${SCRIPT_PATH}/service-lb.yaml
        #kubectl -n ${NAMESPACE} apply -f ${SCRIPT_PATH}/service-lb.yaml
        render_lb_config
        echo "${SVC_LB_CONFIG}" | kubectl apply -n ${NAMESPACE} -f -

    fi
}

function nodeport_discovery() {
    #sleep to get pod scheduled
    sleep 3s
    node=$(kubectl get pod -l role=nfs -o custom-columns=NODE:.spec.nodeName --no-headers -n ${NAMESPACE})
    node_ip=$(kubectl get nodes ${node} -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}')
    node_port=$(kubectl get svc nfs-nodeport -n ${NAMESPACE} -o jsonpath='{range .items[*]}{.spec.ports[?(@.name=="tcp-'${SVC_PORT}'")].nodePort}{"\n"}')
    info "NFS Node IP's:"
    debug "${node_ip}"
    info "NFS Node Port number: "
    debug "${node_port}"
    }

function welcome() {
    if [ -z ${LB_IP} ]; then
        nodeport_discovery
        welcome="You can mount NFS shared volume with the following command:
  mkdir /mnt/shared_dir
  sudo mount -t nfs -o port=NODE_PORT,vers=4 NODE_IP:/ /mnt/shared_dir

  to unmount use the following command:
  sudo umount -f -l /mnt/shared_dir
"
    else
        welcome="You can mount NFS shared volume with the following command:
  mkdir /mnt/shared_dir
  sudo mount -t nfs -o port=${SVC_PORT},vers=4 ${LB_IP}:/ /mnt/shared_dir

  to unmount use the following command:
  sudo umount -f -l /mnt/shared_dir
"
    fi
    info "${welcome}"
}

function deploy() {
    create_ns
    create_pvc
    create_deployment
    create_svc
    welcome
}

function showHelp() {
  echo "Usage: $0 [option...]" >&2
  echo """
  ############################################################################################################################################

     -b    Build and push nfs docker image
     -d    Deploy NFS server
     -l    Use provided Load Balancer IP. If no LB IP provided, NodePort service will be deployed
     -f    Remove existing deployment and deploy a new one

  Example:
    ./deploy-nfs.sh -d -f -l 10.156.133.188

  ############################################################################################################################################
  """
  exit 1
}

while getopts "bdfhl:" opt; do
    case "${opt}" in
        f)
            FORCE="true"
            ;;
        l)
            LB_IP=${OPTARG}
            ;;
        b)
            BUILD="true"
            ;;
        d)
            DEPLOY="true"
            ;;
        h)
            showHelp
            ;;
    esac
done
shift $((OPTIND-1))

[ ${BUILD} = "true" ] && docker_build
[ ${DEPLOY} = "true" ] && deploy