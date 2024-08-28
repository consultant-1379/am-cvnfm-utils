#!/usr/bin/env bash

SFTP_NAMESPACE="sftp-server"
SFTP_RELEASE_NAME="eric-data-sftp-server"
SFTP_REPO="https://arm.sero.gic.ericsson.se/artifactory/proj-pc-eric-sftp-server-released-helm"
SFTP_CHART="$SFTP_REPO/eric-data-sftp-server/eric-data-sftp-server-1.26.0+34.tgz"
SFTP_USER="vnfm"
SFTP_PASSWORD='C.d5[j8Z,g-h#i]Y1!'
SFTP_SERVICE_IP=$(kubectl get service eric-tm-ingress-controller-cr -n eric-crd-ns -o jsonpath='{.spec.loadBalancerIP}{"\n"}')
SFTP_SERVICE_PORT="9022"

function info() {
  echo "[INFO] $1"
}

function error() {
  echo "[ERROR] $1"
  exit 1
}

function createNamespace() {
  info "Checking if namespace $SFTP_NAMESPACE exists"
  kubectl get namespaces | grep -w $SFTP_NAMESPACE
  if [[ $? == 1 ]]; then
    info "Creating namespace $SFTP_NAMESPACE"
    kubectl create namespace $SFTP_NAMESPACE
  else
    info "Namespace $SFTP_NAMESPACE already exists"
  fi
}

function createSftpLocalUserSecretsSecret() {
  info "Creating SFTP local user secrets secret"
  cat <<EOF | kubectl apply -n $SFTP_NAMESPACE -f -
    apiVersion: v1
    kind: Secret
    metadata:
      name: eric-data-sftp-local-user-secrets
    type: Opaque
    stringData:
      eric-data-sftp-local-users-cfg.json: |-
        {
          "description" : "To define users which will be created in local SFTP Server Service.",
          "users": [
            {
              "username": "$SFTP_USER",
              "password": "$SFTP_PASSWORD",
              "roles":
                [
                  "system-admin",
                  "operator"
                ],
              "homeDirectory": "/home/$SFTP_USER"
            }
          ]
        }
EOF
}

function createObjectStoreCredSecret() {
  info "Creating object store cred secret"
  cat <<EOF | kubectl apply -n $SFTP_NAMESPACE -f -
    apiVersion: v1
    kind: Secret
    metadata:
      name: eric-eo-object-store-cred
      labels:
        app: eric-data-object-storage-mn
        chart: eric-data-object-storage-mn
    type: Opaque
    stringData:
      accesskey: $SFTP_USER
      secretkey: $SFTP_PASSWORD
EOF
}

function installSftpServer() {
  info "Running install $SFTP_RELEASE_NAME command"
  command="helm --debug install --atomic $SFTP_RELEASE_NAME $SFTP_CHART --namespace $SFTP_NAMESPACE \
    --set global.security.tls.enabled=false \
    --set service.port=$SFTP_SERVICE_PORT \
    --set service.loadBalancerIP=$SFTP_SERVICE_IP \
    --set configuration.default_bucket_policy='system-admin \* rw:\* \* none' \
    --set userManagement.type=local --set tls.enabled=false \
    --set logTransformer.tls.enabled=false \
    --set objectStorage.accessSecretName=eric-eo-object-store-cred \
    --set certmHostKey.enabled=false --wait"
  info "Install command: $command"
  eval $command
}

function uninstallSftpServer() {
  info "Checking if release $SFTP_RELEASE_NAME exists"
  helm ls -qn $SFTP_NAMESPACE | grep $SFTP_RELEASE_NAME
  if [[ $? == 0 ]]; then
    info "Uninstalling SFTP server"
    command="helm uninstall $SFTP_RELEASE_NAME --namespace $SFTP_NAMESPACE --debug"
    info "Uninstall command: $command"
    eval $command
  else
    info "Release $SFTP_RELEASE_NAME in namespace $SFTP_NAMESPACE not exists, nothing to uninstall"
  fi
}

function deleteNamespace() {
  info "Checking if namespace $SFTP_NAMESPACE exists"
  kubectl get namespaces | grep -w $SFTP_NAMESPACE
  if [[ $? == 0 ]]; then
    info "Deleting namespace $SFTP_NAMESPACE"
    kubectl delete namespace $SFTP_NAMESPACE --wait
  else
    info "Namespace $SFTP_NAMESPACE not found, nothing to delete"
  fi
}

function runInstall() {
  createNamespace
  createSftpLocalUserSecretsSecret
  createObjectStoreCredSecret
  info "Adding and updating helm repo"
  helm repo add proj-pc-eric-sftp-server-released-helm $SFTP_REPO
  helm repo up
  installSftpServer
  if [[ $? == 0 ]]; then
    printLinkAndCredentials
  else
    info "Nothing to print, release not deployed"
  fi
}

function runCleanUp() {
  uninstallSftpServer
  deleteNamespace
}

function printLinkAndCredentials() {
  echo "
  ##############################################################################################################

      SFTP Server:
            url:          sftp://$SFTP_SERVICE_IP:$SFTP_SERVICE_PORT/home/$SFTP_USER/
            user:         $SFTP_USER
            password:     $SFTP_PASSWORD
            bash:         sftp -P $SFTP_SERVICE_PORT $SFTP_USER@$SFTP_SERVICE_IP

  ##############################################################################################################
  "
  exit 1
}

function showHelp() {
  echo "Usage: $0 [option...]" >&2
  echo "
  ##############################################################################################################

      -n   | --namespace <namespace>  Define namespace, otherwise '$SFTP_NAMESPACE' will be used
      -i   | --install                Install SFTP server
      -c   | --cleanup                Uninstall SFTP server
      -h   | --help                   Show help message

  ##############################################################################################################
  "
  exit 1
}

if ! TEMP=$(getopt -o n,i,c,h,* -l namespace,install,cleanup,help,* -q -- "$@"); then
  showHelp
  exit 1
fi

while true; do
  case "$1" in
  -n | --namespace)
    SFTP_NAMESPACE="$2"
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