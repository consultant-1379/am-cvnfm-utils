#!/usr/bin/env bash

NAMESPACE=$1
#check location of kubectl binary and update KUBECTL value
KUBECTL="/usr/local/bin/kubectl"

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
}

function ERROR() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
  exit 1
}

function dropBatchDb() {
  INFO "Start dropping batch DB"
  master="$("$KUBECTL" get pods --selector role=master -n "$NAMESPACE" \
         | awk '/eric-oss-common-postgres/ {print$1}')"
  "$KUBECTL" -n "$NAMESPACE" exec -ti "$master" -c eric-oss-common-postgres \
    -- psql -d batch_manager -U postgres \
    -c 'truncate attachment cascade;'\
    -c 'truncate attachment_content cascade;'\
    -c 'truncate attachment_ref cascade;' \
    -c 'truncate dependency_ref cascade;'\
    -c 'truncate execution_data cascade;'\
    -c 'truncate execution_data_inputs_sensitive_fields cascade;'\
    -c 'truncate execution_data_reachable_milestones cascade;'\
    -c 'truncate execution_data_volatile_data cascade;' \
    -c 'truncate execution_event cascade;'\
    -c 'truncate execution_parameters cascade;'\
    -c 'truncate execution_parameters_dependency cascade;'\
    -c 'truncate execution_parameters_predecessor cascade;'\
    -c 'truncate item cascade;'\
    -c 'truncate item_non_dispatched_events cascade;'\
    -c 'truncate item_tag cascade;'\
    -c 'truncate predecessor_ref cascade;'\
    -c 'truncate target_state_item cascade;'
}

dropBatchDb