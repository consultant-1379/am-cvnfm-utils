#!/usr/bin/env bash

NAMESPACE="eo-deploy"
ENM_NAMESPACE="enm-stub-ns"

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
}

function ERROR() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
  exit 1
}

function checkNamespace() {
  INFO "Checking if $1 namespace exists"
  kubectl get namespace $1
  if [[ $? == 1 ]]; then
    ERROR "Namespace '$1' does not exist on the cluster"
  else
    INFO "Namespace '$1' found on the cluster"
  fi
}

function createEnmSecret() {
  checkNamespace $NAMESPACE
  local enmStubIp=$(kubectl get svc --namespace $ENM_NAMESPACE | awk '/enm/ {print $3}')
  INFO "Checking if enm-secret secret exists"
  kubectl get secret -n $NAMESPACE | grep "enm-secret"
  if [[ $? == 1 ]]; then
    INFO "Creating enm-secret secret"
    kubectl create secret generic enm-secret \
    --from-literal=enm-scripting-ip=$enmStubIp \
    --from-literal=enm-scripting-username=enm \
    --from-literal=enm-scripting-password=enm123! \
    --from-literal=enm-scripting-connection-timeout=20000 \
    --from-literal=enm-scripting-ssh-port=22 \
    --namespace $NAMESPACE
  else
    INFO "enm-secret secret already exists"
  fi
}

function runInstallEnmStub() {
  kubectl create namespace $ENM_NAMESPACE
  INFO "Running install ENM command"
  helm repo add cvnfm-enm-cli-stub https://arm.seli.gic.ericsson.se/artifactory/proj-eo-evnfm-helm
  helm repo update
  helm fetch cvnfm-enm-cli-stub/cvnfm-enm-cli-stub --devel
  command="helm install --atomic cvnfm-enm-cli-stub cvnfm-enm-cli-stub*.tgz --wait --debug --namespace $ENM_NAMESPACE --set service.type=ClusterIP"
  INFO "Install ENM command: $command"
  eval $command
  rm -rf cvnfm-enm-cli-stub*.tgz
  createEnmSecret
}

function uninstallEnmStub() {
  checkNamespace $ENM_NAMESPACE
  if [[ $? == 0 ]]; then
    INFO "Deleting namespace $ENM_NAMESPACE"
    kubectl delete namespace $ENM_NAMESPACE
  fi
}

function showHelp() {
  echo "Usage: $0 [options...]" >&2
  echo """
  ########################################################################################################

     -n    | --namespace <NAMESPACE>    Define EVNFM namespace, otherwise '$NAMESPACE' will be used
     -i    | --install                  Install ENM stub and create ENM secret in EVNFM namespace
     -c    | --cleanup                  Remove ENM stub deployment
     -h    | --help                     Show help message

  --------------------------------------------------------------------------------------------------------

     Example:
        Deploy ENM stub in the '$ENM_NAMESPACE' namespace and create ENM secret in $NAMESPACE ns:
          $0 --namespace $NAMESPACE --install

        Delete ENM stub deployment:
          $0 --cleanup
          Note: command only removes ENM stub deployment. ENM secret on EVNMF namespace is left intact.

  ########################################################################################################
  """
  exit 1
}

if ! TEMP=$(getopt -o n:,i,c,h,* -l namespace:,install,cleanup,help,* -q -- "$@"); then
  showHelp
fi

eval set -- "$TEMP"
while true; do
  case "$1" in
  -n | --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  -i | --install)
    runInstallEnmStub
    shift 1
    ;;
  -c | --cleanup)
    uninstallEnmStub
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