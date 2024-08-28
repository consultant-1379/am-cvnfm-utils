#!/usr/bin/env bash

NAMESPACE="eo-deploy"
COUNTER=30
IDAM_PATH="idm/usermgmt/v1/users"

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
}

function ERROR() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
  exit 1
}

function getCredentials() {
  HOST_VNFM=$(kubectl get vs eric-eo-evnfm-nbi-vnfm-virtualservice -n $NAMESPACE -o jsonpath='{..hosts[0]}')
  USER=$(kubectl get secret eric-evnfm-rbac-default-user -n $NAMESPACE -o jsonpath='{.data.userid}' | base64 -d)
  PASSWORD=$(kubectl get secret eric-evnfm-rbac-default-user -n $NAMESPACE -o jsonpath='{.data.userpasswd}' | base64 -d)
  TOKEN=$(curl -skLX POST 'https://'"$HOST_VNFM"'/auth/v1' -H "Content-Type: application/json" -H "X-login: ${USER}" -H "X-password: ${PASSWORD}")
  URL="https://$HOST_VNFM/$IDAM_PATH"
}

function checkNamespace() {
  INFO "Check if namespace \"$NAMESPACE\" exists"
  if (kubectl get namespace $NAMESPACE -o name > /dev/null); then
    INFO "Namespace \"$NAMESPACE\" is exists"
  else
    ERROR "Namespace \"$NAMESPACE\" not exists"
  fi
}

function getUserPayload() {
cat <<-END
  {
    "user": {
      "username": "$1",
      "status": "Enabled",
      "privileges": [
        "E-VNFM UI User Role",
        "E-VNFM Super User Role",
        "LogViewer",
        "Multi A Domain Role",
        "Multi B Domain Role",
        "default-roles-master",
        "Batch Manager Super User Role"
      ]
    },
    "password": "$PASSWORD",
    "passwordResetFlag": false
  }
END
}

function sendRequest() {
  RESPONSE=$(curl -skLX "$1" "$2" \
    -H "Cookie: JSESSIONID=${TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$3" -w "\t%{http_code}")
}

function createUsers() {
  INFO "Creating new $USERS users"
  for i in $(seq 1 "$USERS"); do
    NEW_USER="vnfm-$i"
    INFO "Checking if user \"$NEW_USER\" exists"
    getUser "$NEW_USER"
    if [[ $? == 1 ]]; then
      INFO "Creating new user \"$NEW_USER\""
      REQUEST_BODY=$(getUserPayload "$NEW_USER")
      sendRequest POST "$URL" "$REQUEST_BODY"
      if [[ $? == 1 || ${RESPONSE: -3} -ne 200 ]]; then
        ERROR "Failed to create new user \"$NEW_USER\". Response: $RESPONSE"
      else
        INFO "New user \"$NEW_USER\" created"
      fi
    else
      INFO "User \"$NEW_USER\" already created"
    fi
  done
}

function getUser() {
  getCredentials
  INFO "Fetching information about \"$1\" user existence"
  sendRequest GET "$URL/$1"
  if [[ ${RESPONSE: -3} -eq 404 ]]; then
    INFO "User \"$1\" not exists. Response: $RESPONSE"
    return 1
  else
    INFO "User \"$1\" exists"
    return 0
  fi
}

function deleteUsers() {
  INFO "Deleting existing $USERS users"
  for i in $(seq 1 "$USERS"); do
    EXIST_USER="vnfm-$i"
    INFO "Checking if user \"$EXIST_USER\" exists"
    getUser "$EXIST_USER"
    if [[ $? == 0 ]]; then
      INFO "Deleting \"$EXIST_USER\" user"
      sendRequest DELETE "$URL"/''"$EXIST_USER"''
      if [[ $? == 1 || ${RESPONSE: -3} -ne 204 ]]; then
        ERROR "Failed to delete existing user \"$EXIST_USER\". Response: $RESPONSE"
      else
        INFO "Existing user \"$EXIST_USER\" deleted"
      fi
    fi
  done
}

function showHelp() {
  echo "Usage: $0 [option...]" >&2
  echo """
  ############################################################################################################################################

     -n    | --namespace <NAMESPACE>    Define namespace, otherwise '$NAMESPACE' will be used
     -a    | --add <USERS>              Define amount of users to create, otherwise '$COUNTER' will be used
     -g    | --get <USER>               Define user name to check if it exists
     -c    | --cleanup <USERS>          Delete amount of users to delete, otherwise '$COUNTER' will be used
     -h    | --help                     Show help message

  ############################################################################################################################################
  """
  exit 1
}

if ! TEMP=$(getopt -o n:,a,g,c,h,* -l namespace:,add,get,cleanup,help,* -q -- "$@"); then
  showHelp
fi

eval set -- "$TEMP"
while true; do
  case "$1" in
  -n | --namespace)
    NAMESPACE="$2"
    checkNamespace
    shift 2
    ;;
  -a | --add)
    USERS=${*: -1}
    if [[ $USERS == "--" ]]; then
      USERS=$COUNTER
    fi
    createUsers
    shift 2
    ;;
  -g | --get)
    getUser $3
    shift 2
    ;;
  -c | --cleanup)
    USERS=${*: -1}
    if [[ $USERS == "--" ]]; then
      USERS=$COUNTER
    fi
    deleteUsers
    shift 2
    ;;
  -h | --help)
    showHelp
    shift 1
    ;;
  *) break
    ;;
  esac
done