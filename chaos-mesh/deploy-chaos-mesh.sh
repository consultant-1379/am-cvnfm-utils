#!/usr/bin/env bash

CHAOS_NAMESPACE="chaos-mesh"
CHAOS_RELEASE_NAME="chaos-mesh"
CHAOS_REPO="https://arm.sero.gic.ericsson.se/artifactory/proj-ews-helm"
CHAOS_CHART="$CHAOS_REPO/$CHAOS_RELEASE_NAME/chaos-mesh-2.5.1.tgz"
CHAOS_HOST="chaos.ews.gic.ericsson.se"

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
}

function ERROR() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
  exit 1
}

function createNamespace() {
  INFO "Checking if namespace $CHAOS_NAMESPACE exists"
  kubectl get namespaces | grep -w $CHAOS_NAMESPACE
  if [[ $? == 1 ]]; then
    INFO "Creating namespace $CHAOS_NAMESPACE"
    kubectl create namespace $CHAOS_NAMESPACE
  else
    INFO "Namespace $CHAOS_NAMESPACE already exists"
  fi
}

function createChaosMeshServiceAccount() {
  INFO "Creating Chaos Mesh cluster scope ServiceAccount"
  cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      namespace: default
      name: chaos-cluster-manager
EOF
}

function createChaosMeshServiceClusterRole() {
  INFO "Creating Chaos Mesh cluster role"
  cat <<EOF | kubectl apply -f -
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: role-chaos-cluster-manager
    rules:
    - apiGroups: [""]
      resources: ["pods", "namespaces"]
      verbs: ["get", "watch", "list"]
    - apiGroups: ["chaos-mesh.org"]
      resources: [ "*" ]
      verbs: ["get", "list", "watch", "create", "delete", "patch", "update"]
EOF
  INFO "Creating Chaos Mesh cluster role binding"
  cat <<EOF | kubectl apply -f -
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: bind-chaos-cluster-manager
    subjects:
    - kind: ServiceAccount
      name: chaos-cluster-manager
      namespace: default
    roleRef:
      kind: ClusterRole
      name: role-chaos-cluster-manager
      apiGroup: rbac.authorization.k8s.io
EOF
}

function createChaosMeshIngress() {
  INFO "Checking if Chaos Mesh dashboard ingress exists"
  kubectl get ingress -n $CHAOS_NAMESPACE | grep 'chaos-dashboard-ingress'
  if [[ $? == 1 ]]; then
    INFO "Creating Chaos Mesh dashboard ingress"
    cat <<EOF | kubectl apply -n $CHAOS_NAMESPACE -f -
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: chaos-dashboard-ingress
      spec:
        ingressClassName: iccr
        rules:
        - host: $CHAOS_HOST
          http:
            paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: chaos-dashboard
                  port:
                    number: 2333
EOF
  else
    INFO "Chaos Mesh dashboard ingress already exists"
  fi
}

function getCredentials() {
  INFO "Getting token name and value for authorization"
  CHAOS_USER=$(kubectl get secret | awk '/chaos-cluster-manager-token/ {print$1}')
  CHAOS_PASSWORD=$(kubectl describe secret $CHAOS_USER | awk -F'      ' '/token:/ {print$2}')
}

function installChaosMeshService() {
  INFO "Running install $CHAOS_RELEASE_NAME release command"
  command="helm --debug install --atomic $CHAOS_RELEASE_NAME $CHAOS_CHART --namespace $CHAOS_NAMESPACE"
  INFO "Install command: $command"
  eval $command
}

function uninstallChaosMeshService() {
  INFO "Checking if release $CHAOS_RELEASE_NAME exists"
  helm ls -qn $CHAOS_NAMESPACE | grep $CHAOS_RELEASE_NAME
  if [[ $? == 0 ]]; then
    INFO "Uninstalling Chaos Mesh service"
    command="helm uninstall $CHAOS_RELEASE_NAME --namespace $CHAOS_NAMESPACE --debug"
    INFO "Uninstall command: $command"
    eval $command
  else
    INFO "Release $CHAOS_RELEASE_NAME in namespace $CHAOS_NAMESPACE not exists, nothing to uninstall"
  fi
}

function deleteChaosMeshServiceServiceAccount() {
  INFO "Checking if Chaos Mesh ServiceAccount exists"
  kubectl get serviceaccount -o name | grep 'chaos-cluster-manager'
  if [[ $? == 0 ]]; then
    kubectl delete serviceaccount chaos-cluster-manager
  else
    INFO "Chaos Mesh ServiceAccount doesn't exist"
  fi
}

function deleteChaosMeshServiceClusterRole() {
  INFO "Checking if Chaos Mesh ClusterRoleBinding exists"
  kubectl get clusterrolebinding -o name | grep 'bind-chaos-cluster-manager'
  if [[ $? == 0 ]]; then
    kubectl delete clusterrolebinding bind-chaos-cluster-manager
  else
    INFO "Chaos Mesh ClusterRoleBinding doesn't exist"
  fi
  INFO "Checking if Chaos Mesh ClusterRole exists"
  kubectl get clusterrole -o name | grep 'role-chaos-cluster-manager'
  if [[ $? == 0 ]]; then
    kubectl delete clusterrole role-chaos-cluster-manager
  else
    INFO "Chaos Mesh ClusterRole doesn't exist"
  fi
}

function deleteNamespace() {
  INFO "Checking if namespace $CHAOS_NAMESPACE exists"
  kubectl get namespaces | grep -w $CHAOS_NAMESPACE
  if [[ $? == 0 ]]; then
    INFO "Deleting namespace $CHAOS_NAMESPACE"
    kubectl delete namespace $CHAOS_NAMESPACE --wait
  else
    INFO "Namespace $CHAOS_NAMESPACE not found, nothing to delete"
  fi
}

function runInstall() {
  createChaosMeshServiceAccount
  createChaosMeshServiceClusterRole
  createNamespace
  createChaosMeshIngress
  installChaosMeshService
  if [[ $? == 0 ]]; then
    getCredentials
    printLinkAndCredentials
  else
    INFO "Nothing to print, release not deployed"
  fi
}

function runCleanUp() {
  uninstallChaosMeshService
  deleteChaosMeshServiceServiceAccount
  deleteChaosMeshServiceClusterRole
  deleteNamespace
}

function printLinkAndCredentials() {
  echo """
  ##############################################################################################################

      Chaos Mesh Service:
            url:          http://$CHAOS_HOST
            user:         $CHAOS_USER
            password:     $CHAOS_PASSWORD

      Note: Authorization is a mandatory after deployment and will be needed only once.

  ##############################################################################################################
  """
  exit 1
}

function showHelp() {
  echo "Usage: $0 [option...]" >&2
  echo """
  ##############################################################################################################

      -n   | --namespace <namespace>  Define namespace, otherwise '$CHAOS_NAMESPACE' will be used
      -h   | --host <host url>        Define host URL, otherwise '$CHAOS_HOST' will be used
      -i   | --install                Install Chaos Mesh service
      -c   | --cleanup                Uninstall Chaos Mesh service
      -h   | --help                   Show help message

  ##############################################################################################################
  """
  exit 1
}

if ! TEMP=$(getopt -o n,h,i,c,h,* -l namespace,host,install,cleanup,help,* -q -- "$@"); then
  showHelp
  exit 1
fi

while true; do
  case "$1" in
  -n | --namespace)
    CHAOS_NAMESPACE="$2"
    shift 2
    ;;
  -h | --host)
    CHAOS_HOST="$2"
    shift 2
    ;;
  -i | --install)
    runInstall
    shift 1
    ;;
  -c | --cleanup)
    runCleanUp
    shift 1
    ;;
  -h | --help)
    showHelp
    shift 1
    ;;
  *) break
    ;;
  esac
done