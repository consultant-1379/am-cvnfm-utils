#!/usr/bin/env bash

NAMESPACE="eo-deploy"
SERVICES=(
    "application-manager-postgres"
    "eric-am-common-wfs"
    "eric-am-common-wfs-ui"
    "eric-am-onboarding-service"
    "eric-eo-batch-manager"
    "eric-eo-evnfm-crypto"
    "eric-eo-evnfm-nbi"
    "eric-eo-fh-event-to-alarm-adapter"
    "eric-eo-lm-consumer"
    "eric-lcm-container-registry"
    "eric-lcm-helm-chart-registry"
    "eric-vnfm-orchestrator-service"
)

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
}

function ERROR() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
  exit 1
}

function checkNamespaceExistence() {
  INFO "Checking if namespace \"$NAMESPACE\" exists"
  if ! (kubectl get namespace $NAMESPACE -o name > /dev/null); then
    ERROR "Namespace \"$NAMESPACE\" not exists"
  fi
}

verifyLogs() {
  checkNamespaceExistence
  for service in "${SERVICES[@]}"; do
    INFO "Verifying logs presence in $service service pods"
    for pod in $(kubectl get pods -l app.kubernetes.io/name="$service" -n $NAMESPACE --no-headers -o custom-columns=":metadata.name"); do
      for container in $(kubectl --namespace $NAMESPACE get pod "$pod" -o jsonpath='{.spec.containers[0].name}' ); do
        logs=$(kubectl --namespace $NAMESPACE logs "$pod" -c "$container")
        if [ -z "$logs" ]; then ERROR "No logs in $pod pod $container container"; fi
      done
    done
  done
}

function showHelp() {
  echo "Usage: $0 [option...]" >&2
  echo """
  ############################################################################################################################################

     -n    | --namespace <NAMESPACE>    Define namespace, otherwise '$NAMESPACE' will be used
     -v    | --verify                   Verify logs presence in main container of each pod for CVNFM services
     -h    | --help                     Show help message

  ############################################################################################################################################
  """
  exit 1
}

if ! TEMP=$(getopt -o n:,v,h,* -l namespace:,verify,help,* -q -- "$@"); then
  showHelp
fi

eval set -- "$TEMP"
while true; do
  case "$1" in
  -n | --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  -v | --verify)
    verifyLogs
    shift 1
    ;;
  -h | --help)
    showHelp
    shift 1
    ;;
  *)
    break
    ;;
  esac
done
