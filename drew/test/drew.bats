#!/usr/bin/env bats
#
# COPYRIGHT Ericsson 2023
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

#set up defaul, global vars
DETIK_CLIENT_NAME="kubectl"
DETIK_CLIENT_NAMESPACE="zlukdmy-ns"
BATS_VERSION="1.10.0"
DEPLOY_SCRIPT="drew.sh"
KUBECTL="kubectl"
KUBECTL_VERSION="1.20.0"
DEBUG_DETIK="true"
CONFIG_FILE="drew.conf"

# Load libraries
bats_load_library 'bats-support'
bats_load_library 'bats-assert'
bats_load_library 'bats-file'
bats_load_library 'bats-detik/lib/utils.bash'
bats_load_library 'bats-detik/lib/linter.bash'
bats_load_library 'bats-detik/lib/detik.bash'
#setup() {
##some action to setup tests, examles: prepare namespace, create role or something else
#}


### Config test ###

@test "Is exist config file" {
  assert_exists "${PWD}/${CONFIG_FILE}"
}

@test "Is readable config file" {
  assert_file_permission 644 "${PWD}/${CONFIG_FILE}"
}

@test "Is not empty config file" {
  assert_file_not_empty "${PWD}/${CONFIG_FILE}"
}

### brew is exist and executable
@test "Is exist script file" {
  assert_exists "${PWD}/${DEPLOY_SCRIPT}"
}

@test "Is executable script file" {
  assert_file_permission 755 "${PWD}/${DEPLOY_SCRIPT}"
}

@test "Is not empty script file" {
  assert_file_not_empty "${PWD}/${DEPLOY_SCRIPT}"
}

### Script can start and show help
@test "Sucesfull start" {
  skip
  bats_require_minimum_version 1.5.0
  run -0 "${PWD}/${DEPLOY_SCRIPT}"
}

@test "invoking help" {
#  skip
  bats_require_minimum_version 1.5.0
  run -1 "${PWD}/${DEPLOY_SCRIPT}" -h
  [ "${lines[0]}" = 'Usage: ./drew.sh [option...]' ]
}

### Test deployment ###
@test "Sucesfull start prepare" {
  skip #needs kube config file
  bats_require_minimum_version 1.5.0
  run -0 "${PWD}/${DEPLOY_SCRIPT}" -p
}

@test "kubectl is present" {
  skip
  bats_require_minimum_version 1.5.0
  run -0 "${PWD}/${KUBECTL}" version
  [ "${lines[0]}" = 'Client Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.1", GitCommit:"5e58841cce77d4bc13713ad2b91fa0d961e69192", GitTreeState:"clean", BuildDate:"2021-05-12T14:18:45Z", GoVersion:"go1.16.4", Compiler:"gc", Platform:"linux/amd64"}' ]
}

@test "verify the prepare stage for deployment" {
  skip
  bats_require_minimum_version 1.5.0
	run -0 "${PWD}/${$DEPLOY_SCRIPT}"

	run verify "there is 1 namespace named '$DETIK_CLIENT_NAMESPACE'"
	[ "${status}" -eq 0 ]

	run verify "there is 1 secret named 'iam-tls-secret'"
	debug "Command output is: $output"
	[ "${status}" -eq 0 ]

	run verify "there is 1 secret named 'eric-eo-database-pg-secret'"
	[ "${status}" -eq 0 ]

	run verify "there is 1 secret named 'vnfm-tls-secret'"
  [ "${status}" -eq 0 ]

}

@test "verify the deployment" {
  skip
  bats_require_minimum_version 1.5.0
	run -0 "${$DEPLOY_SCRIPT}"

	sleep 20

	run verify "there is 1 namespace named '${DETIK_CLIENT_NAMESPACE}'"
	[ "$status" -eq 0 ]

	run verify "there is 1 deployments named 'eric-eo-api-gateway'"
	[ "${status}" -eq 0 ]

	run verify "there is 1 deployments named 'eric-eo-evnfm-crypto'"
	[ "${status}" -eq 0 ]

	run verify "there is 1 deployments named 'eric-vnfm-orchestrator-service'"
  [ "${status}" -eq 0 ]

}