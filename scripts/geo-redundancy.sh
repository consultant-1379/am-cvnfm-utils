#!/usr/bin/env bash

CURRENT_ARGS=( "$@" )

set --
. deploy-evnfm.sh

set -- "${CURRENT_ARGS[@]}"

API_TOKEN=""

function authenticate() {
  HOST=$1
  INFO "Authenticating at $HOST..."
  API_TOKEN=$(curl -s -k -X POST -H "X-Login: $GR_USER" -H "X-Password: $PASSWORD" "https://$HOST/auth/v1")
}

function getStatus() {
  HOST=$1
  INFO "Getting status from $HOST..."
  curl -s -w "\n" -k -H "Cookie: JSESSIONID=$API_TOKEN" -H "Content-Type: application/json" "https://$HOST/api/v1/clusters/metadata" | jsonPrettyPrint
}

function getAvailability() {
  HOST=$1
  INFO "Getting switchover availability for $HOST..."
  curl -s -w "\n" -k -H "Cookie: JSESSIONID=$API_TOKEN" -H "Content-Type: application/json" "https://$HOST/api/v1/switchover/availability" | jsonPrettyPrint
}

function switchover() {
  HOST=$1
  INFO "Starting switchover from $HOST..."
  curl -s -w "\n" -k -X POST -H "Cookie: JSESSIONID=$API_TOKEN" -H "Content-Type: application/json" \
      -d "{\"secondaries\": [\"$HOST\"], \"override\": false}" https://$HOST/api/v1/switchover | jsonPrettyPrint
}

function jsonPrettyPrint() {
  INPUT=$(cat < /dev/stdin)
  if [ `command -v jq` ]; then
    echo $INPUT | jq
  else
    echo $INPUT
  fi
}

function showGrHelp() {
  echo "Usage: $0 [option...]" >&2
  echo """
  ############################################################################################################################################

     status <host>                                Show status for the <host>
     switchover <host>                            Start switchover from <primary_host>
     availability <host>                          Show switchover availability for <host>
     -h    | --help                               Show help message

     Examples:
       $0 status $HOST_GR
       $0 availability $HOST_GR
       $0 switchover $HOST_GR

  ############################################################################################################################################
  """
  exit 1
}

case "$1" in
  status)
    HOST=$2
    authenticate $HOST
    getStatus $HOST
    ;;
  switchover)
    HOST=$2
    authenticate $HOST
    switchover $HOST
    ;;
  availability)
    HOST=$2
    authenticate $HOST
    getAvailability $HOST
    ;;
  -h | --help | *)
    showGrHelp
    ;;
esac
