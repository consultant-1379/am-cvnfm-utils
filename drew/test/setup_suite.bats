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

setup_suite() {
echo "Run once for the set of tests, before start"
#set up defaul, global vars
DETIK_CLIENT_NAME="kubectl"
DETIK_CLIENT_NAMESPACE="zlukdmy-ns"
BATS_VERSION="1.10.0"
DEPLOY_SCRIPT="./drew.sh"
KUBECTL="kubectl"
KUBECTL_VERSION="1.20.0"
DEBUG_DETIK="true"
CONFIG_FILE="config.sh"


}

teardown_suite() {
  skip
  bats_require_minimum_version 1.5.0
  echo "Run once for the set of tests, after all"
  run -0 $DEPLOY_SCRIPT -c
}