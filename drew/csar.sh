#!/usr/bin/env bash
#
# COPYRIGHT Ericsson 2024
#
#
#
# The copyright to the computer program(s) herein is the property of
#
# Ericsson Inc. The programs may be used and/or copied only with written
#
# permission from Ericsson Inc. or in accordance with the terms and
#
# conditions stipulated in the agreement/contract under which the
#
# program(s) have been supplied.
#

RELEASE_VERSION="${1}"
DM_VERSION="${2}"
WORKING_DIR="${3:-$(dirname "$0")}"
SCRIPT_NAME="$(basename "$0")"
TOOL_NAME="${SCRIPT_NAME%.*}"
CSARS_PATH="https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-drop-generic-local/csars/"

# Constants
PRODUCT="EO CVNFM"

set -o errexit
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$TOOL_NAME] [${FUNCNAME[0]}]: $1"
}

function ERROR() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$TOOL_NAME] [${FUNCNAME[0]}]: $1"
  exit 1
}

function sourceConfig() {
  [[ -z "$CONFIG_PATH" ]] && CONFIG_PATH="$WORKING_DIR"/"$TOOL_NAME".conf
  [[ -f "$CONFIG_PATH" ]] || ERROR "Please check if drew config file exists"
  # shellcheck source=/dev/null
  source "$CONFIG_PATH"
}

function preparingReleaseCandidate() {  # TBD Whole function will be removed, right?
  INFO "Creating workdir"
  mkdir -p "$WORKING_DIR/$RELEASE_VERSION"
  INFO "Downloading Release Candidate"
  if [ ! -f "$WORKING_DIR/$RELEASE_VERSION/eric-eo-helmfile-$RELEASE_VERSION.tgz" ]; then
    wget -nc https://arm.seli.gic.ericsson.se/artifactory/proj-eo-helm/eric-eo-helmfile/eric-eo-helmfile-"$RELEASE_VERSION".tgz -P "$WORKING_DIR/$RELEASE_VERSION"
  else
    INFO "Release Candidate is already downloaded"
  fi
}

function preparingDM() {  # TBD Whole function will be refactored, right?
  INFO "Loading image to docker"
  docker images | grep "$DM_VERSION"
  if [[ $? == 1 ]]; then
    wget -nc --user="$NAME" --password="$PASS" "$CSARS_PATH"/dm/deployment-manager-"$DM_VERSION".zip
    unzip -jnq deployment-manager-"$DM_VERSION".zip 'deployment-manager.tar'
    docker load --input deployment-manager.tar
    rm -rf deployment-manager-"$DM_VERSION".zip
    rm -rf deployment-manager.tar
  else
    INFO "Deployment manager image is already exists in docker"
  fi
}

function getCSARs() { # TBD Whole function will be refactored, right?
  INFO "Get release csars for installation"
  tar -xf "$WORKING_DIR/$RELEASE_VERSION/eric-eo-helmfile-$RELEASE_VERSION".tgz -C "$WORKING_DIR/$RELEASE_VERSION"
  cloud=$(grep -A10 'name: eric-cloud-native-base' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  common=$(grep -A10 'name: eric-oss-common' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  cncs=$(grep -A10 'name: eric-cncs' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  cvnfm=$(grep -A10 'name: eric-eo-evnfm$' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  ofoc=$(grep -A10 'name: eric-oss-function-orchestration-common' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  cnbase=$(grep -A10 'name: eric-cnbase-oss-config' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  vmvnfm=$(grep -A10 'name: eric-eo-evnfm-vm' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  mesh=$(grep -A10 'name: eric-cloud-native-service-mesh' "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/helmfile.yaml | awk -F' ' '/version/ {print$2}')
  downloadCSAR "eric-cloud-native-base" $cloud
  downloadCSAR "eric-oss-common-base" $common
  downloadCSAR "eric-cncs-oss-config" $cncs
  downloadCSAR "eric-eo-evnfm" $cvnfm
  downloadCSAR "eric-oss-function-orchestration-common" $ofoc
  downloadCSAR "eric-cnbase-oss-config" $cnbase
  downloadCSAR "eric-cloud-native-service-mesh" $mesh
  downloadCSAR "eric-eo-evnfm-vm" $vmvnfm
  rm -rf "$WORKING_DIR/$RELEASE_VERSION"/eric-eo-helmfile/
}

function downloadCSAR() {
  local csar_name="${1}"
  local csar_version="${2}"
   if [[ ! -f "$WORKING_DIR/$RELEASE_VERSION/$csar_name-$csar_version.csar" ]]; then
      wget -nc --user="$NAME" --password="$PASS" "$CSARS_PATH/$csar_name/$csar_version/$csar_name-$csar_version.csar" -P "$WORKING_DIR/$RELEASE_VERSION"
    else
      INFO "$csar_name chart is already present"
    fi
}

function showHelp() {

  printf """
Usage: %s RELEASE_VERSION DM_VERSION WORKING_DIR
%s installation and upgrade tool

Arguments:
  RELEASE_VERSION             release version of %s to
  DM_VERSION                  version of deployment manager to use
  WORKING_DIR                 directory to download csars into, by default current directory
""" "$(basename "$0")" "$PRODUCT" "$PRODUCT"
}

if [[ "$#" -ne 2 ]] && [[ "$#" -ne 3 ]]; then
  showHelp >&2
  exit 1
fi

preparingReleaseCandidate
preparingDM
getCSARs