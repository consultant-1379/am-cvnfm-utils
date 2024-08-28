#!/usr/bin/env bash

NAMESPACE="eo-deploy"
INSTANCES=1000
INSTANCE_NAME="nrm-instance"

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
}

function ERROR() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
  exit 1
}

function getDatabaseMasterReplica() {
  INFO "Checking if namespace $NAMESPACE exists"
  if (kubectl get namespace $NAMESPACE -o name > /dev/null); then
    MASTER=$(kubectl get pods --selector role=master -n $NAMESPACE | awk '/application-manager/ {print$1}')
  else
    ERROR "Namespace \"$NAMESPACE\" not exists"
  fi
}

function injectData() {
  kubectl -n $NAMESPACE exec "$MASTER" -c application-manager-postgres -- psql -d orchestrator -U postgres \
          -c "DO \$$
                  DECLARE current_instance_id VARCHAR;
                  DECLARE current_instance_name VARCHAR;
                  DECLARE current_instance_count INT;
                  DECLARE instance_namespace VARCHAR;
                  DECLARE instance_cluster VARCHAR;
                  DECLARE modify_operations_count INT;
                  DECLARE new_instance_id VARCHAR;
                  DECLARE instances_count INT;
                  DECLARE new_instance_name VARCHAR;
                  DECLARE ccvp_operation_id VARCHAR;
                  DECLARE operation_id VARCHAR;
                  DECLARE last_operation_id VARCHAR;
                  DECLARE operation_timestamp TIMESTAMP;
              BEGIN
                  current_instance_name := '$INSTANCE_NAME';

                  -- Check if instance is present in database
                  SELECT COUNT(vnf_id) FROM app_vnf_instance WHERE vnf_instance_name = current_instance_name INTO current_instance_count;
                  IF current_instance_count = 0
                  THEN
                      RAISE 'No instances with name \"%\" are present in DB. Please perform an instantiation before duplicating instance', current_instance_name USING ERRCODE = '22000';
                  END IF;

                  SELECT vnf_id FROM app_vnf_instance WHERE vnf_instance_name = current_instance_name INTO current_instance_id;
                  SELECT \"namespace\" FROM app_vnf_instance WHERE vnf_id = current_instance_id INTO instance_namespace;
                  SELECT config_file_name FROM cluster_config_instances cci WHERE cci.instance_id = current_instance_id INTO instance_cluster;
                  instances_count := floor(random() * 100000 + 1)::INT;
                  modify_operations_count := 8;
                  SELECT gen_random_uuid() INTO new_instance_id;
                  SELECT CONCAT('dummy-nrm-', instances_count) INTO new_instance_name;
                  SELECT gen_random_uuid() INTO ccvp_operation_id;
                  SELECT gen_random_uuid() INTO last_operation_id;

                  -- Insert dummy VNF instance
                  INSERT INTO app_vnf_instance (vnf_id, vnf_instance_name, vnf_instance_description, vnfd_id, vnf_provider, vnf_product_name,
                                              vnf_software_version, vnfd_version, vnf_pkg_id, instantiation_state, cluster_name, \"namespace\",
                                              current_life_cycle_operation_id, oss_topology, instantiate_oss_topology, add_node_oss_topology, added_to_oss,
                                              combined_additional_params, combined_values_file, policies, resource_details ,mano_controlled_scaling,
                                              temp_instance, override_global_registry, metadata, alarm_supervision_status, clean_up_resources, is_heal_supported,
                                              sitebasic_file, oss_node_protocol_file, sensitive_info, bro_endpoint_url, instantiation_level,
                                              vnf_info_modifiable_attributes_extensions, crd_namespace, supported_operations, is_rel4, helm_client_version)
                  SELECT new_instance_id, new_instance_name, avi.vnf_instance_description, avi.vnfd_id, avi.vnf_provider, avi.vnf_product_name,
                        avi.vnf_software_version, avi.vnfd_version, avi.vnf_pkg_id, avi.instantiation_state, avi.cluster_name, avi.\"namespace\",
                        last_operation_id, avi.oss_topology, avi.instantiate_oss_topology, avi.add_node_oss_topology, avi.added_to_oss,
                          avi.combined_additional_params, avi.combined_values_file, avi.policies, avi.resource_details ,avi.mano_controlled_scaling,
                        avi.temp_instance, avi.override_global_registry, avi.metadata, avi.alarm_supervision_status, avi.clean_up_resources, avi.is_heal_supported,
                        avi.sitebasic_file, avi.oss_node_protocol_file, avi.sensitive_info, avi.bro_endpoint_url, avi.instantiation_level,
                        avi.vnf_info_modifiable_attributes_extensions, avi.crd_namespace, avi.supported_operations, avi.is_rel4, avi.helm_client_version
                  FROM app_vnf_instance avi WHERE avi.vnf_id = current_instance_id;

                  -- Insert Helm charts for the instance
                  INSERT INTO helm_chart (id, vnf_id, helm_chart_url, priority, release_name, state, revision_number, retry_count, delete_pvc_state,
                                          downsize_state, replica_details, helm_chart_name, helm_chart_version, helm_chart_type, helm_chart_artifact_key)
                  VALUES
                      (gen_random_uuid(), new_instance_id, 'http://eric-lcm-helm-chart-registry.test-ns.svc.cluster.local:8080/onboarded/charts/eric-sec-sip-tls-crd-4.2.0+32.tgz', 1,
                      'eric-sec-sip-tls-crd', 'COMPLETED', NULL, 0, NULL, NULL, '{}', 'eric-sec-sip-tls-crd', '4.2.0+32', 'CRD'::public.\"chart_type_enum\", 'crd_package1'),
                      (gen_random_uuid(), new_instance_id, 'http://eric-lcm-helm-chart-registry.test-ns.svc.cluster.local:8080/onboarded/charts/eric-sec-certm-crd-3.16.0+48.tgz', 2,
                      'eric-sec-certm-crd', 'COMPLETED', NULL, 0, NULL, NULL, '{}', 'eric-sec-certm-crd', '3.16.0+48', 'CRD'::public.\"chart_type_enum\", 'crd_package2'),
                      (gen_random_uuid(), new_instance_id, 'http://eric-lcm-helm-chart-registry.test-ns.svc.cluster.local:8080/onboarded/charts/scale-crd-1.0.0.tgz', 3,
                      'scale-crd', 'COMPLETED', NULL, 0, NULL, NULL, '{}', 'scale-crd', '1.0.0', 'CRD'::public.\"chart_type_enum\", 'crd_package3'),
                      (gen_random_uuid(), new_instance_id, 'http://eric-lcm-helm-chart-registry.test-ns.svc.cluster.local:8080/onboarded/charts/spider-app-4.0.1.tgz', 5,
                      CONCAT(current_instance_name, '-2'), 'COMPLETED', '1', 0, NULL, NULL, '{"eric-pm-bulk-reporter":{"minReplicasParameterName":null,"minReplicasCount":null,"maxReplicasParameterName":null,"maxReplicasCount":null,"scalingParameterName":"eric-pm-bulk-reporter.replicaCount","currentReplicaCount":2,"autoScalingEnabledParameterName":null,"autoScalingEnabledValue":false}}',
                      'spider-app', '4.0.1', 'CNF'::public.\"chart_type_enum\", 'helm_package2'),
                      (gen_random_uuid(), new_instance_id, 'http://eric-lcm-helm-chart-registry.test-ns.svc.cluster.local:8080/onboarded/charts/test-scale-chart-4.0.0.tgz', 4,
                      current_instance_name, 'COMPLETED', '1', 0, NULL, NULL, '{"test-cnf":{"minReplicasParameterName":null,"minReplicasCount":null,"maxReplicasParameterName":null,"maxReplicasCount":null,"scalingParameterName":"vnfc1.test-cnf.replicaCount","currentReplicaCount":1,"autoScalingEnabledParameterName":null,"autoScalingEnabledValue":false},"test-cnf-vnfc1":{"minReplicasParameterName":"vnfc1.minReplicas","minReplicasCount":null,"maxReplicasParameterName":"vnfc1.maxReplicas","maxReplicasCount":null,"scalingParameterName":"vnfc1.replicaCount","currentReplicaCount":1,"autoScalingEnabledParameterName":"vnfc1.autoscaling.enabled","autoScalingEnabledValue":false},"test-cnf-vnfc3":{"minReplicasParameterName":null,"minReplicasCount":null,"maxReplicasParameterName":null,"maxReplicasCount":null,"scalingParameterName":"vnfc3.replicaCount","currentReplicaCount":1,"autoScalingEnabledParameterName":null,"autoScalingEnabledValue":false},"test-cnf-vnfc4":{"minReplicasParameterName":null,"minReplicasCount":null,"maxReplicasParameterName":null,"maxReplicasCount":null,"scalingParameterName":"vnfc4.replicaCount","currentReplicaCount":1,"autoScalingEnabledParameterName":null,"autoScalingEnabledValue":false},"test-cnf-vnfc5":{"minReplicasParameterName":"vnfc5.minReplicas","minReplicasCount":1,"maxReplicasParameterName":"vnfc5.maxReplicas","maxReplicasCount":1,"scalingParameterName":"vnfc5.replicaCount","currentReplicaCount":1,"autoScalingEnabledParameterName":"vnfc5.autoscaling.enabled","autoScalingEnabledValue":true}}',
                      'test-scale-chart', '4.0.0', 'CNF'::public.\"chart_type_enum\", 'helm_package1');

                  -- Insert Scale Info
                  INSERT INTO scale_info (scale_info_id, vnf_instance_id, aspect_id, scale_level)
                  VALUES
                    (gen_random_uuid(), new_instance_id,'Aspect5',1),
                    (gen_random_uuid(), new_instance_id,'Aspect2',1),
                    (gen_random_uuid(), new_instance_id,'Aspect3',1),
                    (gen_random_uuid(), new_instance_id,'Aspect1',1);

                  -- Insert Instantiate operation
                  INSERT INTO app_lifecycle_operations (operation_occurrence_id, vnf_instance_id, operation_state, state_entered_time, start_time,
                                                        grant_id, lifecycle_operation_type, automatic_invocation, operation_params, cancel_pending,
                                                        cancel_mode, error,values_file_params, vnf_software_version, vnf_product_name, expired_application_time,
                                                        combined_additional_params, combined_values_file, source_vnfd_id, target_vnfd_id, resource_details,
                                                        scale_info_entities, delete_node_failed, delete_node_error_message, delete_node_finished,
                                                        set_alarm_supervision_error_message, application_timeout, downsize_allowed, is_auto_rollback_allowed,
                                                        rollback_failure_pattern, instantiation_level, vnf_info_modifiable_attributes_extensions, rollback_pattern,
                                                        username, helm_client_version)
                  VALUES
                      (gen_random_uuid(), new_instance_id, 'COMPLETED', (now()-interval '15 minutes')::timestamp, (now()-interval '15 minutes')::timestamp,
                      NULL, 'INSTANTIATE', false, NULL, false, NULL, NULL, NULL, '1.0.0s', 'spider-app-multi-nrm-750-pods', '2050-04-06 12:28:30.697',
                      '{\"namespace\":\"test-rel4-ns\",\"helmNoHooks\":false,\"disableOpenapiValidation\":true}',NULL,'multi-chart-etsi-rel4-5fcb086597','multi-chart-etsi-rel4-5fcb086597','{\"test-cnf-vnfc3\":1,\"test-cnf-vnfc4\":1,\"test-cnf\":1,\"test-cnf-vnfc5\":1,\"eric-pm-bulk-reporter\":1,\"test-cnf-vnfc1\":1}','[{\"scaleInfoId\":\"2fd03ac4-b0a1-4042-8814-938c223b40e4\",\"aspectId\":\"Aspect2\",\"scaleLevel\":0},{\"scaleInfoId\":\"baaccdab-1ff0-4629-abd3-fcdc684cd756\",\"aspectId\":\"Aspect5\",\"scaleLevel\":0},{\"scaleInfoId\":\"d0feaf02-0c64-4cfd-a0da-50a6b5c0d7a2\",\"aspectId\":\"Aspect3\",\"scaleLevel\":0},{\"scaleInfoId\":\"f34d5aec-5765-41e3-b24f-694d0f6b950c\",\"aspectId\":\"Aspect1\",\"scaleLevel\":1}]',false,NULL,false,NULL,'600',false,false,NULL,'instantiation_level_1','{\"vnfControlledScaling\":{\"Aspect5\":\"CISMControlled\",\"Aspect1\":\"ManualControlled\",\"Aspect2\":\"ManualControlled\",\"Aspect3\":\"ManualControlled\"}}',NULL,'vnfm','latest');

                  -- Insert CCVP operation
                  INSERT INTO app_lifecycle_operations (operation_occurrence_id,vnf_instance_id,operation_state,state_entered_time,start_time,grant_id,lifecycle_operation_type,automatic_invocation,operation_params,cancel_pending,cancel_mode,error,values_file_params,vnf_software_version,vnf_product_name,expired_application_time,combined_additional_params,combined_values_file,source_vnfd_id,target_vnfd_id,resource_details,scale_info_entities,delete_node_failed,delete_node_error_message,delete_node_finished,set_alarm_supervision_error_message,application_timeout,downsize_allowed,is_auto_rollback_allowed,rollback_failure_pattern,instantiation_level,vnf_info_modifiable_attributes_extensions,rollback_pattern,username,helm_client_version) VALUES
                          (ccvp_operation_id, new_instance_id,'COMPLETED',(now()-interval '13 minutes')::timestamp,(now()-interval '13 minutes')::timestamp,NULL,'CHANGE_VNFPKG',false,NULL,false,NULL,NULL,NULL,'1.0.40s','spider-app-multi-b-etsi-tosca-rel4','2023-04-13 09:13:58.050','{\"disableOpenapiValidation\":true}',NULL,'multi-chart-etsi-rel4-5fcb086597','multi-chart-etsi-rel4-b-455379754e37',NULL,'[{\"scaleInfoId\":null,\"aspectId\":\"Aspect4\",\"scaleLevel\":0},{\"scaleInfoId\":null,\"aspectId\":\"Aspect1\",\"scaleLevel\":1},{\"scaleInfoId\":null,\"aspectId\":\"Aspect2\",\"scaleLevel\":0}]',false,NULL,false,NULL,'600',true,false,NULL,'instantiation_level_1','{\"vnfControlledScaling\":{\"Aspect4\":\"ManualControlled\",\"Aspect1\":\"ManualControlled\",\"Aspect2\":\"ManualControlled\"}}',NULL,'vnfm',NULL);

                  -- Insert cluster config association
                  INSERT INTO cluster_config_instances (config_file_name, instance_id)
                  VALUES (instance_cluster, new_instance_id);

                  -- Insert instance namespace details
                  INSERT INTO vnfinstance_namespace_details (id, vnf_id, \"namespace\", cluster_server, namespace_deletion_in_progess)
                  SELECT gen_random_uuid(), new_instance_id, vnd.\"namespace\", vnd.cluster_server, 'f'
                  FROM vnfinstance_namespace_details vnd WHERE vnd.vnf_id = current_instance_id;

                  -- Propagate modify info operations
                  FOR i IN 1..modify_operations_count LOOP
                    IF i = modify_operations_count THEN
                        operation_id := last_operation_id;
                        operation_timestamp := now();
                    ELSE
                        SELECT gen_random_uuid() INTO operation_id;
                        operation_timestamp := now() - interval '5 minutes';
                    END IF;

                    -- propagate modify operation
                    INSERT INTO app_lifecycle_operations (operation_occurrence_id,vnf_instance_id,operation_state,state_entered_time,start_time,grant_id,lifecycle_operation_type,automatic_invocation,operation_params,cancel_pending,cancel_mode,error,values_file_params,vnf_software_version,vnf_product_name,expired_application_time,combined_additional_params,combined_values_file,source_vnfd_id,target_vnfd_id,resource_details,scale_info_entities,delete_node_failed,delete_node_error_message,delete_node_finished,set_alarm_supervision_error_message,application_timeout,downsize_allowed,is_auto_rollback_allowed,rollback_failure_pattern,instantiation_level,vnf_info_modifiable_attributes_extensions,rollback_pattern,username,helm_client_version) VALUES
                    (operation_id, new_instance_id,'COMPLETED',operation_timestamp,operation_timestamp,NULL,'MODIFY_INFO',false,NULL,false,NULL,NULL,NULL,'1.0.0s','spider-app-multi-b-etsi-tosca-rel4','2023-04-06 14:13:03.70796',NULL,NULL,'multi-chart-etsi-rel4-b-455379754e37',NULL,NULL,'[{\"scaleInfoId\":\"2fd03ac4-b0a1-4042-8814-938c223b40e4\",\"aspectId\":\"Aspect2\",\"scaleLevel\":0},{\"scaleInfoId\":\"baaccdab-1ff0-4629-abd3-fcdc684cd756\",\"aspectId\":\"Aspect5\",\"scaleLevel\":0},{\"scaleInfoId\":\"d0feaf02-0c64-4cfd-a0da-50a6b5c0d7a2\",\"aspectId\":\"Aspect3\",\"scaleLevel\":0},{\"scaleInfoId\":\"f34d5aec-5765-41e3-b24f-694d0f6b950c\",\"aspectId\":\"Aspect1\",\"scaleLevel\":1}]',false,NULL,false,NULL,'3600',false,false,NULL,'instantiation_level_1','{\"vnfControlledScaling\":{\"Aspect5\":\"CISMControlled\",\"Aspect1\":\"ManualControlled\",\"Aspect2\":\"ManualControlled\",\"Aspect3\":\"ManualControlled\"}}',NULL,'vnfm','latest');

                    -- propagate changes info
                    INSERT INTO changed_info (id,vnf_pkg_id,vnf_instance_name,vnf_instance_description,metadata,vnfd_id,vnf_provider,vnf_product_name,vnf_software_version,vnfd_version,vnf_info_modifiable_attributes_extensions) VALUES
                    (operation_id,NULL,NULL,'test description',NULL,NULL,NULL,NULL,NULL,NULL,'{\"vnfControlledScaling\":{\"Aspect5\":\"CISMControlled\",\"Aspect1\":\"ManualControlled\",\"Aspect2\":\"ManualControlled\",\"Aspect3\":\"ManualControlled\"}}');
                  END LOOP;
              END;
              \$$" 1> /dev/null
}

function propagateOperationsForRealInstance() {
    kubectl -n $NAMESPACE exec "$MASTER" -c application-manager-postgres -- psql -d orchestrator -U postgres \
          -c "DO \$$
                  DECLARE current_instance_name VARCHAR;
                  DECLARE current_instance_id VARCHAR;
                  DECLARE current_instance_count INT;
                  DECLARE modify_operations_count INT;
                  DECLARE operation_id VARCHAR;
                  DECLARE last_operation_id VARCHAR;
                  DECLARE operation_timestamp TIMESTAMP;
              BEGIN
                  current_instance_name := '$INSTANCE_NAME';

                  -- Check if instance is present in database
                  SELECT COUNT(vnf_id) FROM app_vnf_instance WHERE vnf_instance_name = current_instance_name INTO current_instance_count;
                  IF current_instance_count = 0
                  THEN
                      RAISE 'No instances with name \"%\" are present in DB. Please perform an instantiation before duplicating instance', current_instance_name USING ERRCODE = '22000';
                  END IF;

                  SELECT vnf_id FROM app_vnf_instance WHERE vnf_instance_name = current_instance_name INTO current_instance_id;

                  SELECT gen_random_uuid() INTO last_operation_id;

                  -- Propagate modify info operations for real instance 9 times
                  FOR i IN 1..9 LOOP
                    IF i = 9 THEN
                        operation_id := last_operation_id;
                        operation_timestamp := now();
                        UPDATE app_vnf_instance SET current_life_cycle_operation_id = operation_id WHERE vnf_id = current_instance_id;
                    ELSE
                        SELECT gen_random_uuid() INTO operation_id;
                        operation_timestamp := now() - interval '1 minutes';
                    END IF;

                    -- Propagate modify operation
                    INSERT INTO app_lifecycle_operations (operation_occurrence_id,vnf_instance_id,operation_state,state_entered_time,start_time,grant_id,lifecycle_operation_type,automatic_invocation,operation_params,cancel_pending,cancel_mode,error,values_file_params,vnf_software_version,vnf_product_name,expired_application_time,combined_additional_params,combined_values_file,source_vnfd_id,target_vnfd_id,resource_details,scale_info_entities,delete_node_failed,delete_node_error_message,delete_node_finished,set_alarm_supervision_error_message,application_timeout,downsize_allowed,is_auto_rollback_allowed,rollback_failure_pattern,instantiation_level,vnf_info_modifiable_attributes_extensions,rollback_pattern,username,helm_client_version) VALUES
                    	(operation_id, current_instance_id,'COMPLETED',operation_timestamp,operation_timestamp,NULL,'MODIFY_INFO',false,NULL,false,NULL,NULL,NULL,'1.0.0s','spider-app-a-nrm-package-750-pods','2023-04-06 14:13:03.70796',NULL,NULL,'spider-app-nrm-750-pods-67us15sp91',NULL,NULL,'[{\"scaleInfoId\":\"2fd03ac4-b0a1-4042-8814-938c223b40e4\",\"aspectId\":\"Aspect2\",\"scaleLevel\":0},{\"scaleInfoId\":\"baaccdab-1ff0-4629-abd3-fcdc684cd756\",\"aspectId\":\"Aspect5\",\"scaleLevel\":0},{\"scaleInfoId\":\"d0feaf02-0c64-4cfd-a0da-50a6b5c0d7a2\",\"aspectId\":\"Aspect3\",\"scaleLevel\":0},{\"scaleInfoId\":\"f34d5aec-5765-41e3-b24f-694d0f6b950c\",\"aspectId\":\"Aspect1\",\"scaleLevel\":1}]',false,NULL,false,NULL,'3600',false,false,NULL,'instantiation_level_1','{\"vnfControlledScaling\":{\"Aspect5\":\"CISMControlled\",\"Aspect1\":\"ManualControlled\",\"Aspect2\":\"ManualControlled\",\"Aspect3\":\"ManualControlled\"}}',NULL,'vnfm','latest');

                    -- propagate changes info
                    INSERT INTO changed_info (id,vnf_pkg_id,vnf_instance_name,vnf_instance_description,metadata,vnfd_id,vnf_provider,vnf_product_name,vnf_software_version,vnfd_version,vnf_info_modifiable_attributes_extensions) VALUES
                    	(operation_id,NULL,NULL,'test description',NULL,NULL,NULL,NULL,NULL,NULL,'{\"vnfControlledScaling\":{\"Aspect5\":\"CISMControlled\",\"Aspect1\":\"ManualControlled\",\"Aspect2\":\"ManualControlled\",\"Aspect3\":\"ManualControlled\"}}');
                  END LOOP;
              END;
		      \$$" 1> /dev/null
}

function propagateOrchestratorDB() {
  for i in $(seq 1 "$1"); do
    INFO "Creating instance №$i";
    injectData
  done
}

function cleanupOrchestratorDB() {
  kubectl -n $NAMESPACE exec -ti "$MASTER" -c application-manager-postgres -- psql -d orchestrator -U postgres \
    -c 'truncate app_lifecycle_operations cascade;' \
    -c 'truncate app_vnf_instance cascade;'
}

function showHelp() {
  echo "Usage: $0 [option...]" >&2
  echo """
  ############################################################################################################################################

     -n    | --namespace <NAMESPACE>    Define namespace, otherwise '$NAMESPACE' will be used
     -i    | --instance <INSTANCE_NAME> Name of duplicated instance, if not specified '$INSTANCE_NAME' will be used
     -a    | --add <CNFS>               Propagate Orchestrator database with $INSTANCES vnf instances and 10k operations
     -c    | --cleanup                  Remove vnf instances and operations from Orchestrator database
     -h    | --help                     Show help message

     Example:
       bash $0 -n <namespace> -i <instance name> -a <instances count>
     Note: Script creates (<instances count> - 1) records, because first instance is a referent one

  ############################################################################################################################################
  """
  exit 1
}

if ! TEMP=$(getopt -o a,c,i:,n:,h,* -l add,cleanup,instance:,namespace:,help,* -q -- "$@"); then
  showHelp
fi

eval set -- "$TEMP"
while true; do
  case "$1" in
  -n | --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  -i | --instance)
    INSTANCE_NAME="$2"
    shift 2
    ;;
  -a | --add)
    CNFS=${*: -1}
    if [[ $CNFS == "--" ]]; then
      CNFS=$INSTANCES
    fi
    getDatabaseMasterReplica
    INSTANCES_THREAD=$(($CNFS/10))
    propagateOperationsForRealInstance
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $INSTANCES_THREAD &
    propagateOrchestratorDB $(($INSTANCES_THREAD-1)) &
    wait
    shift 2
    ;;
  -c | --cleanup)
    getDatabaseMasterReplica
    cleanupOrchestratorDB
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