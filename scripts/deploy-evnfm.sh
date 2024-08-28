#!/usr/bin/env bash

# Uncomment to use different kubeconfig
#export KUBECONFIG="$HOME/.kube/oss-orch-eocm-geo-35650-kubeconfig.txt"

SIGNUM=$(whoami) # do not change this
NAMESPACE="$SIGNUM"-ns # change this for alternative deployment e.g. "$SIGNUM"-<text>-ns
ENM_NAMESPACE="$SIGNUM"-enm-ns

ICCR_NAME="iccr"
ICCR_GLOBAL="ingressClass: $ICCR_NAME"
CLUSTER_ROLE_HELMFILE=2.7.0-153
# TODO Remove after 23.6
NELS_HELMFILE=2.11.0-138
NELS_LATEST_VALUES=2.29.0-218
SM_HELMFILE=2.19.0-166
ENM_LB_IPS="10.156.133.180 10.156.133.181 10.156.133.182 10.156.133.183 10.156.133.184"
############ Geo redundancy variable
GR_ENABLED="${GR_ENABLED:=false}"
GR_USER="${GR_USER:=gr-user}"
GR_SITE_ROLE="${GR_SITE_ROLE:=PRIMARY}" # Possible values 'PRIMARY', 'SECONDARY'
GR_SECONDARY_SITE_HOST="${GR_SECONDARY_SITE_HOST:=gr.$SIGNUM.gr1-geo-35650.flexilab.sero.gic.ericsson.se}"
GR_SECONDARY_SITE_REGISTRY="${GR_SECONDARY_SITE_REGISTRY:=gr.$SIGNUM.gr1-geo-35650.flexilab.sero.gic.ericsson.se}" # Should be replaced with primary registry if secondary site deployed
SFTP_URL="${SFTP_URL:=sftp://10.158.164.125:9022/home/vnfm}"
########################################
#   No edits below this line
########################################

if kubectl get ns | grep $NAMESPACE  > /dev/null; then
  ENV_NAME=$(kubectl get ns $NAMESPACE --no-headers -o custom-columns=":metadata.labels.envName")
fi

case $(kubectl config current-context) in
*haber002)
  DOMAIN="ews.gic.ericsson.se"
  CLUSTER="$(kubectl config current-context)-$ENV_NAME"
  ;;
*hart070)
  DOMAIN="ews.gic.ericsson.se"
  CLUSTER="$ENV_NAME-$(kubectl config current-context)"
  ;;
*oss-orch-eocm-geo-35650-kubeconfig)
  DOMAIN="flexilab.sero.gic.ericsson.se"
  CLUSTER="gr1-geo-35650"
  ;;
esac

CLUSTER=${CLUSTER#*@}
CRD_NAMESPACE="eric-crd-ns"
LB_IP=$(curl test.$CLUSTER.$DOMAIN -vs -m 5 2>&1 | grep -Eom1 "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
USER="vnfm"
PASSWORD="ciTesting123!"
SFTP_PASSWORD="C.d5[j8Z,g-h#i]Y1!"
export GERRIT_USERNAME="cvnfmadm10"
export GERRIT_PASSWORD="SNWVb8WyASUmhQ7SEx?hVpHR"
GLOBAL_REGISTRY_URL="armdocker.rnd.ericsson.se"
HOST_DOC_REG="docker.$SIGNUM.$CLUSTER.$DOMAIN"
HOST_HELM_REG="helm.$SIGNUM.$CLUSTER.$DOMAIN"
HOST_IDAM="iam.$SIGNUM.$CLUSTER.$DOMAIN"
HOST_VNFM="vnfm.$SIGNUM.$CLUSTER.$DOMAIN"
HOST_GAS="gas.$SIGNUM.$CLUSTER.$DOMAIN"
HOST_GR="gr.$SIGNUM.$CLUSTER.$DOMAIN"
HOST_REGISTRY="registry.$SIGNUM.$CLUSTER.$DOMAIN"
HOST_NELS="nelsaas-vnf2-thrift.sero.gic.ericsson.se"
#HOST_NELS="eric-test-nels-simulator.nels-simulator-ns.svc.cluster.local" # NeLS simulator should be installed and configured
IP_NELS="10.155.142.69"
ARTIFACTORY_PATH="https://arm.seli.gic.ericsson.se/artifactory"
HELM_MIGRATOR_PATH="$ARTIFACTORY_PATH/proj-eric-oss-base-platform-generic-local/eric-oss-helm-migrator/0.1.0-47/helm-migrator-0.1.0-47.zip"
EVNFM_CHART_REPO="https://gerrit.ericsson.se/a/projects/OSS%2Fcom.ericsson.orchestration.mgmt%2Fam-integration-charts"
SIGNED_CERTS_REPO="https://gerrit.ericsson.se/a/projects/OSS%2Fcom.ericsson.orchestration.mgmt%2Fevnfm-testing-artifacts"
SIGNED_CERTS_PATH="branches/master/files/certificates"
# Choose only one of next 2 options. If local path is set - chart will be copied instead of downloading (with changes for dev purposes)
HELMFILE_CHART_PATH_RELEASE="$ARTIFACTORY_PATH/proj-eo-helm/eric-eo-helmfile"
HELMFILE_CHART_PATH_SNAPSHOT="$ARTIFACTORY_PATH/proj-eo-snapshot-helm/eric-eo-helmfile"
#HELMFILE_CHART_PATH="/local/helmfile"
WORKING_DIR="./certs/$SIGNUM-$CLUSTER"
VALUES_FILE="values.yaml"
HELM_CHART="$ARTIFACTORY_PATH/proj-eo-helm/eric-eo/eric-eo-1.42.0-248.tgz" # obsolete - for EVNFM releases till 1.42.0-248
HELM_RELEASENAME="$SIGNUM-eric-eo-evnfm"
SELF_SIGN_KEY="$WORKING_DIR/intermediate-ca.key"
SELF_SIGN_CRT="$WORKING_DIR/intermediate-ca.crt"
APPLICATION_MANAGER_POSTGRES_PVC_SIZE="8Gi"
PG_BRA_STORAGE_REQUESTS="10Gi" # must be not less as APPLICATION_MANAGER_POSTGRES_PVC_SIZE * 1.2
PG_BRA_STORAGE_LIMITS="12Gi" # must be not less as APPLICATION_MANAGER_POSTGRES_PVC_SIZE * 1.5
CONTAINER_REGISTRY_PVC_SIZE="50Gi" # default value is 450Gi. Decreased for haber002 for dev purposes
CTRL_BRO_PVC_SIZE="20Gi"
OSMN_PVC_SIZE="10Gi"
REGISTRY_CREDENTIALS_USER="usertest"
REGISTRY_CREDENTIALS_PASS="passtest"
NELS_ENABLED="true"
ENM_STUB_ENABLED="false"
CONTAINER_REGISTRY_ENABLED="false"
BRO_ENABLED="false"


declare -a hosts=("$HOST_DOC_REG" "$HOST_HELM_REG" "$HOST_IDAM" "$HOST_VNFM" "$HOST_GAS" "$HOST_GR")

# values for Helmfile deployment
function renderValues() {
values_yaml=$(cat <<END
global:
  hosts:
    gas: $HOST_GAS
    iam: $HOST_IDAM
    vnfm: $HOST_VNFM
    gr: $HOST_GR
$ICCR_GLOBAL_TEMPLATE
  registry:
    url: $GLOBAL_REGISTRY_URL
    username: $GERRIT_USERNAME
    password: $GERRIT_PASSWORD
    imagePullPolicy: Always
  support:
    ipv6:
      enabled: false
  timezone: UTC
$NELS_LICENSING_GLOBAL_TEMPLATE
$NELS_LATEST_LICENSING_GLOBAL_TEMPLATE

tags:
  eoCm: false
  eoEvnfm: true
  eoVmvnfm: false

eric-cloud-native-base:
  eric-sec-key-management:
    replicaCount:
      kms: 1
  eric-cloud-native-kvdb-rd-operand:
    replicationFactor: 0
  eric-fh-snmp-alarm-provider:
    sendAlarm: false
  eric-data-object-storage-mn:
    persistentVolumeClaim:
      size: $OSMN_PVC_SIZE
  eric-ctrl-bro:
    persistence:
      persistentVolumeClaim:
        size: $CTRL_BRO_PVC_SIZE
    sftp:
      password: '$SFTP_PASSWORD'
      username: '$USER'
  eric-data-search-engine:
    service:
      network:
        protocol:
          IPv6: false
  eric-sec-access-mgmt:
    replicaCount: 1
    brAgent:
      enabled: false
    accountManager:
      enabled: false
      inactivityThreshold: 9999
$ICCR_SEC_ACCESS_TEMPLATE
  eric-sec-access-mgmt-db-pg:
    highAvailability:
      replicaCount: 1
    brAgent:
      enabled: false
  eric-log-transformer:
    egress:
      syslog:
        enabled: false
        remoteHosts: []
        tls:
          enabled: false
  eric-cm-mediator:
    replicaCount: 1
  eric-cm-mediator-db-pg:
    highAvailability:
      replicaCount: 1
  eric-data-distributed-coordinator-ed:
    pods:
      dced:
        replicas: 1
    brAgent:
      enabled: false
  eric-sec-sip-tls:
    replicaCount: 1
  eric-oss-common-base:
    highAvailability:
      replicaCount: 1
$ICCR_CNCS_TEMPLATE
$NELS_LICENSING_CLOUD_NATIVE_TEMPLATE
$NELS_LATEST_LICENSING_CLOUD_NATIVE_TEMPLATE

geo-redundancy:
  enabled: $GR_ENABLED
backup-controller:
  enabled: true

eric-oss-common-base:
$SM_CNCS_TEMPLATE
  sessionTokens:
    maxIdleTimeSecs: 3600
    maxSessionDurationSecs: 36000
  gas:
    defaultUser:
      password: gasTesting123!
      username: gas-user
  system-user:
    credentials:
      password: systemTesting123!
      username: system-user
  eric-eo-usermgmt:
    replicaCount: 1
  eric-eo-usermgmt-ui:
    replicaCount: 1
  eric-oss-common-postgres:
    brAgent:
      enabled: false
    highAvailability:
      replicaCount: 1
  eric-adp-gui-aggregator-service:
    replicaCount: 1

eric-oss-function-orchestration-common:
  eric-eo-batch-manager:
    replicaCount: 1
  eric-eo-lm-consumer:
    replicaCount: 1
  eric-eo-evnfm-crypto:
    replicaCount: 1
  eric-eo-evnfm-nbi:
    replicaCount: 1
    eric-evnfm-rbac:
      defaultUser:
        password: "$PASSWORD"
        username: "$USER"
      eric-eo-evnfm-drac:
        enabled: false
        domainRoles:
  eric-am-onboarding-service:
    replicaCount: 1
    userSecret: container-credentials
    onboarding:
      skipCertificateValidation: false
$GR_TEMPLATE

eric-eo-evnfm:
  application-manager-postgres:
    resources:
      bra:
        requests:
          ephemeral-storage: $PG_BRA_STORAGE_REQUESTS
        limits:
          ephemeral-storage: $PG_BRA_STORAGE_LIMITS
    persistence:
      backup:
        enabled: false
    brAgent:
      enabled: false
    persistentVolumeClaim:
      size: $APPLICATION_MANAGER_POSTGRES_PVC_SIZE
    highAvailability:
      replicaCount: 1
  eric-am-common-wfs:
    replicaCount: 1
    userSecret: container-credentials
  eric-am-common-wfs-ui:
    replicaCount: 1
  eric-lcm-container-registry:
    HA: false
    ingress:
      hostname: $HOST_DOC_REG
    persistence:
      persistentVolumeClaim:
        size: $CONTAINER_REGISTRY_PVC_SIZE
  eric-lcm-helm-chart-registry:
    ingress:
      hostname: ''
    env:
      secret:
        BASIC_AUTH_PASS: $PASSWORD
        BASIC_AUTH_USER: admin
  eric-vnfm-orchestrator-service:
    replicaCount: 1
    oss:
      topology:
        secretName: ${EnmSecretNameValue:-null}
    smallstack:
      application: true
$CONTAINER_REGISTRY_TEMPLATE

eric-cloud-native-service-mesh:
  eric-mesh-controller:
    replicaCount: 1
END
)
}

# Values for deployments till 1.42.0-248 EO helm chart (before helmfile introduction)
old_values_yaml=$(cat <<END
global:
  registry:
    url: $GLOBAL_REGISTRY_URL
    username: $GERRIT_USERNAME
    password: $GERRIT_PASSWORD
  hosts:
    iam: $HOST_IDAM
    vnfm: $HOST_VNFM
    gas: $HOST_GAS
  $ICCR_GLOBAL
  logging:
    enabled: false
system-user:
  credentials:
    username: "system-user"
    password: "ciTestingUser123!"
eric-ctrl-bro:
  persistence:
    persistentVolumeClaim:
      size: $CTRL_BRO_PVC_SIZE
  sftp:
    username: $USER
    password: $USER
eric-eo-evnfm:
  application-manager-postgres:
    persistence:
      backup:
        enabled: false
    brAgent:
      enabled: false
    highAvailability:
      replicaCount: 1
    persistentVolumeClaim:
      size: $APPLICATION_MANAGER_POSTGRES_PVC_SIZE
  eric-am-common-wfs:
    service:
      account: evnfm
  eric-lcm-container-registry:
    ingress:
      ingressClass: "$ICCR_NAME"
      hostname: $HOST_DOC_REG
    persistence:
      persistentVolumeClaim:
        size: $CONTAINER_REGISTRY_PVC_SIZE
    brAgent:
      enabled: false
  eric-vnfm-orchestrator-service:
    smallstack:
      application: true
  eric-eo-usermgmt:
    iam:
      admin:
        url: https://$HOST_IDAM
  eric-lcm-helm-chart-registry:
    ingress:
      enabled: true
      ingressClass: "$ICCR_NAME"
      hostname: $HOST_HELM_REG
    brAgent:
      enabled: false
eric-sec-access-mgmt:
  highAvailability:
    replicaCount: 1
  ingress:
    ingressClass: "$ICCR_NAME"
    hostname: $HOST_IDAM
  egress:
    ldap:
      certificates:
        trustedCertificateListSecret: ""
gas:
  defaultUser:
    username: gasuser
    password: gasTesting123!
image:
  pullPolicy: Always
tags:
  eoEvnfm: true
eric-pm-server:
  enabled: true
  prometheus.yml: |
    remote_write:
      - url: http://eric-oss-metrics-stager:1234/receive
eric-oss-metrics-stager:
  enabled: false
eric-oss-udc:
  enabled: false
  autoUpload:
    enabled: true
    account: "upload@ddpeo.athtem.eei.ericsson.se"
    ddpid: "lmi_test"
    password: "_!upLoad"
eric-oss-common-postgres:
  brAgent:
    enabled: false
  highAvailability:
    replicaCount: 1
eric-eo-eai-database-pg:
  brAgent:
    enabled: false
backup-controller:
  enabled: false
eric-eo-evnfm-nbi:
  eric-evnfm-rbac:
    defaultUser:
      username: "$USER"
      password: "$PASSWORD"
$ICCR_CHART
END
)

# Enabling/disabling services in helmfile. For lightweight deployment - disable log-shipper/transformer, data-search-engine/curator etc.
renderOptionality() {
optionality_yaml=$(cat <<END
optionality:
  eric-cloud-native-base:
    eric-cm-mediator:
      enabled: true
    eric-fh-snmp-alarm-provider:
      enabled: false
    eric-data-document-database-pg:
      enabled: false
    eric-fh-alarm-handler-db-pg:
      enabled: false
    eric-sec-access-mgmt-db-pg:
      enabled: true
    eric-lm-combined-server-db-pg:
      enabled: $NELS_ENABLED
    eric-cm-mediator-db-pg:
      enabled: true
    eric-pm-server:
      enabled: false
    eric-data-message-bus-kf:
      enabled: false
    eric-data-coordinator-zk:
      enabled: false
    eric-sec-key-management:
      enabled: true
    eric-fh-alarm-handler:
      enabled: false
    eric-sec-access-mgmt:
      enabled: true
    eric-sec-sip-tls:
      enabled: true
    eric-odca-diagnostic-data-collector:
      enabled: false
    eric-data-distributed-coordinator-ed:
      enabled: true
    eric-sec-certm:
      enabled: true
    eric-ctrl-bro:
      enabled: $BRO_ENABLED
    eric-lm-combined-server:
      enabled: $NELS_ENABLED
    eric-data-search-engine:
      enabled: false
    eric-data-search-engine-curator:
      enabled: false
    eric-log-transformer:
      enabled: false
    eric-log-shipper:
      enabled: false
    eric-data-object-storage-mn:
      enabled: false
    eric-dst-agent:
      enabled: false
    eric-dst-collector:
      enabled: false
    eric-tm-ingress-controller-cr:
      enabled: $ICCR_ENABLED
    eric-si-application-sys-info-handler:
      enabled: false
    eric-data-key-value-database-rd:
      enabled: true
    eric-cloud-native-kvdb-rd-operand:
      enabled: true
  eric-oss-common-base:
    eric-eo-api-gateway:
      enabled: true
    eric-eo-usermgmt:
      enabled: true
    eric-eo-usermgmt-ui:
      enabled: true
    eric-eo-common-br-agent:
      enabled: false
    eric-oss-common-postgres:
      enabled: true
    eric-adp-gui-aggregator-service:
      enabled: true
    eric-eo-eai:
      enabled: false
    eric-eo-eai-database-pg:
      enabled: false
    eric-eo-subsystem-management:
      enabled: false
    eric-eo-subsystem-management-database-pg:
      enabled: false
    eric-eo-subsystemsmgmt-ui:
      enabled: false
    eric-eo-credential-manager:
      enabled: false
    eric-eo-onboarding:
      enabled: false
    eric-eo-ecmsol005-adapter:
      enabled: false
    eric-eo-ecmsol005-stub:
      enabled: false
    eric-oss-metrics-stager:
      enabled: false
    eric-oss-ddc:
      enabled: false
    eric-pm-kube-state-metrics:
      enabled: false
    eric-pm-alert-manager:
      enabled: false
    eric-cnom-server:
      enabled: false
    service-mesh-ingress-gateway:
      enabled: $SM_ENABLED
    service-mesh-egress-gateway:
      enabled: false
    eric-dst-query:
      enabled: false
    eric-oss-help-aggregator:
      enabled: false
    eric-oss-key-management-agent:
      enabled: false
    eric-sef-exposure-api-manager-client:
      enabled: false
    eric-oss-license-consumer:
      enabled: false
    eric-oss-license-consumer-database-pg:
      enabled: false
    eric-oss-certificate-management-ui:
      enabled: false
    eric-oss-ui-settings:
      enabled: false
    eric-oss-ui-settings-database-pg:
      enabled: false
  eric-oss-function-orchestration-common:
    eric-eo-lm-consumer:
      enabled: true
    eric-eo-fh-event-to-alarm-adapter:
      enabled: false
    eric-eo-evnfm-nbi:
      enabled: true
    eric-eo-evnfm-crypto:
      enabled: true
    evnfm-toscao:
      enabled: true
    eric-am-onboarding-service:
      enabled: true
    eric-eo-batch-manager:
      enabled: true
    eric-gr-bur-orchestrator:
      enabled: $GR_ENABLED
    eric-gr-bur-database-pg:
      enabled: $GR_ENABLED
END
)
}

NELS_LICENSING_GLOBAL_TEMPLATE=$(cat <<END
  ericsson:
    licensing:
      licenseDomains:
        - productType: "Ericsson_Orchestrator"
          swltId: "STB-EVNFM-1"
          customerId: 800141
          applicationId: "800141_STB-EVNFM-1_Ericsson_Orchestrator"
      nelsConfiguration:
        primary:
          hostname: "$HOST_NELS"
END
)

NELS_LATEST_LICENSING_GLOBAL_TEMPLATE=$(cat <<END
  ericsson:
    licensing:
      licenseDomains:
        - productType: "Ericsson_Orchestrator"
          swltId: "STB-EVNFM-1"
          customerId: 800141
          applicationId: "800141_STB-EVNFM-1_Ericsson_Orchestrator"
  licensing:
    sites:
      - hostname: $HOST_NELS
        ip: $IP_NELS
        priority: 0
END
)

NELS_LICENSING_CLOUD_NATIVE_TEMPLATE=$(cat <<END
  eric-lm-combined-server-db-pg:
    enabled: true
    highAvailability:
      replicaCount: 1
  eric-si-application-sys-info-handler:
    enabled: true
    asih:
      uploadSwimInformation: false
  eric-lm-combined-server:
    enabled: true
    replicaCount:
      licenseServerClient: 1
      licenseConsumerHandler: 1
    licenseServerClient:
      licenseServer:
        thrift:
          host: "$HOST_NELS"
END
)

NELS_LATEST_LICENSING_CLOUD_NATIVE_TEMPLATE=$(cat <<END
  eric-lm-combined-server-db-pg:
    enabled: true
    highAvailability:
      replicaCount: 1
  eric-si-application-sys-info-handler:
    enabled: true
    asih:
      uploadSwimInformation: false
  eric-lm-combined-server:
    enabled: true
    replicaCount:
      licenseServerClient: 1
      licenseConsumerHandler: 1
END
)

ICCR_GLOBAL_TEMPLATE=$(cat << END
  ingressClass: "$ENV_NAME"
END
)

ICCR_SEC_ACCESS_TEMPLATE=$(cat << END
    ingress:
      hostname: $HOST_IDAM
      ingressClass: "$ENV_NAME"
END
)

ICCR_CNCS_TEMPLATE=$(cat << END
  eric-tm-ingress-controller-cr:
    service:
      loadBalancerIP: "$LB_IP"
      annotations:
        cloudProviderLB: {}
      externalTrafficPolicy: "Local"
END
)

SM_CNCS_TEMPLATE=$(cat << END
  service-mesh-ingress-gateway:
    replicaCount: 1
    service:
      loadBalancerIP: "$LB_IP"
      annotations:
        cloudProviderLB: {}
END
)

GR_TEMPLATE=$(cat << END
  eric-gr-bur-orchestrator:
    credentials:
      username: "$GR_USER"
      password: "$PASSWORD"
    gr:
      bro:
        autoDelete:
          backupsLimit: 10
      sftp:
        url: "$SFTP_URL"
        username: "$USER"
        password: "$SFTP_PASSWORD"
      cluster:
        role: $GR_SITE_ROLE
        secondary_hostnames:
        - $GR_SECONDARY_SITE_HOST
      registry:
        secondarySiteContainerRegistryHostname: $GR_SECONDARY_SITE_REGISTRY
        userSecretName: container-credentials
        usernameKey: userid
        passwordKey: userpasswd
      primaryCycleIntervalSeconds: 100
END
)

CONTAINER_REGISTRY_TEMPLATE=$(cat << END
  eric-global-lcm-container-registry:
    hostname: $HOST_REGISTRY
    username: $USER
    password: $PASSWORD
    enabled: true
END
)

# Templates for intermediate-ca certificate
SELF_SIGN_CRT_TLP=$(cat <<END
-----BEGIN CERTIFICATE-----
MIIDXjCCAkYCCQD0PDbGCtaOyzANBgkqhkiG9w0BAQsFADBwMRkwFwYDVQQDDBBT
ZWxmU2lnbmVkUm9vdENBMREwDwYDVQQKDAhFcmljc3NvbjELMAkGA1UECwwCSVQx
EjAQBgNVBAcMCVN0b2NraG9sbTESMBAGA1UECAwJU3RvY2tob2xtMQswCQYDVQQG
EwJTRTAgFw0yMTExMTkxNzM5MzFaGA8yMDUxMTExMjE3MzkzMVowcDEZMBcGA1UE
AwwQU2VsZlNpZ25lZFJvb3RDQTERMA8GA1UECgwIRXJpY3Nzb24xCzAJBgNVBAsM
AklUMRIwEAYDVQQHDAlTdG9ja2hvbG0xEjAQBgNVBAgMCVN0b2NraG9sbTELMAkG
A1UEBhMCU0UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDMJBdwN4ED
vF8CWPzgvjabZqVS3ftaUzolSqEGD7yvlY0j2ai7w/5+Y+YOJ5rgpHqDyDZ+ntvS
bGdjHrpnE9Tx0CcPXmHe+MSxqrOEqx1cbLLi80MxPjujdId2cup22aPdcXhh71+i
sVuYzHpzdRE4/LKabN8AnPfv1bruRax31O49dIbAq+RUj4cYMEZCcZNid316rwsv
ymzwNpbFRlsABfimwZV/2PPhBoWxGqk5mCz93pYnronQKLar9FtttRUQAxI5R5y2
wLfLWfrgpwGwd6XEN1aZJX/CYx/3QHZ+t1oe/fBcHpnzEVtdMMM3filgIJSeSVO0
tIq8/nzAAiLdAgMBAAEwDQYJKoZIhvcNAQELBQADggEBALvoW28xdNnNleuApIlg
d+lXKYnavVY/tBHg8q3n+0OQc4wJ7BoMIbJhvts2zwxXWwkLquvKnc/NfapPSEEC
8Mly2bmgmF2RdAc5s/Ojz/lzdXEvJFa93/0KTlTlO4Of/6kv7XJ1Q3rA2ybLGBSi
SZVTYl65sEdlGj1DGTwTBOG49TupFcJ6rK/BtyWFOnEAFpnPXYh2GlB+WTsUVFqn
RZ5lLK+EtncTu3HE5WBSkKHhFxbV48dTOP2SSaDTVjjLlbzTEWvj5BOlFYTxPsTB
pWvyN2AUEWG4b+Ez7vxz7ccRnHebjl5uJrztQpXS1TSG0mFV2q7+eQcqsSCLyORv
a0g=
-----END CERTIFICATE-----
END
)

SELF_SIGN_KEY_TLP=$(cat <<END
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDMJBdwN4EDvF8C
WPzgvjabZqVS3ftaUzolSqEGD7yvlY0j2ai7w/5+Y+YOJ5rgpHqDyDZ+ntvSbGdj
HrpnE9Tx0CcPXmHe+MSxqrOEqx1cbLLi80MxPjujdId2cup22aPdcXhh71+isVuY
zHpzdRE4/LKabN8AnPfv1bruRax31O49dIbAq+RUj4cYMEZCcZNid316rwsvymzw
NpbFRlsABfimwZV/2PPhBoWxGqk5mCz93pYnronQKLar9FtttRUQAxI5R5y2wLfL
WfrgpwGwd6XEN1aZJX/CYx/3QHZ+t1oe/fBcHpnzEVtdMMM3filgIJSeSVO0tIq8
/nzAAiLdAgMBAAECggEBAIcgmNcyFldXuHhAWVuW7WSeZG7e+4OFteZ7aO0vO5Hq
Z5vEdxmbGfmlvOG/u5hZp7NVsyTLmOzHzwPgkjiq+vj59PEKY7SJbQHB4cS+09eb
KCpsJh0Reb6v4v84ABWd6QcrFimVnvN9fQk+yQtmAXl8Y+kuicrJHKGIE42nVwuW
GxKpB3Ys7h881uGT/YAZc01UNVoGtBtE/VnHfILEFcFHZbuCnz899sI6p+yiXho8
Gv7WjW73zNxBo0J1syF8B5Kt37OTBe2z29jZ7BPPhxJBIDF7RkROcXB4YZmRB35H
qkD4LC3XO92S7tccJvXgvp4KOfCnZItuWuSAUkRfu80CgYEA7sVl58NVc1rbvrBd
kx1mlGzatam5rJjQCw5aqQOH6pWfk4gxKxlBZnH0cz0yzRvyx2ApERtuyrW7aV5k
dL2UA/P/b/u3nnUokSHfiICyaokEc2eqm9E7ijw6XEt7MEcOg8vxbBbumHcRNzcx
bzY2canjsOBbyOx+y1iuZuZaxYsCgYEA2t8AwidVjet4A8fuRo/j8H2w7FfiGe3w
BadciCqIrpgsuPVTDm5r8U397i0mCVPGzWIS/j5fV7C0ObdgdTf3zKU57a9Hvee+
cM/0m6M5vc1nA5XD16hwSKGVSvxfE7IGoLPNbpVRR0v1xrhpgIwN9at7GykpnXvo
c6gcR7MPVjcCgYEAsJoOQnqGhFiqeYMG4x321kchCQZtD4zDK7pFMgcri0V5juxH
uaHnbndQn7+fCHfofLDSDxYkPwhlgozPbk0d4kKhJtmeOTRceeP86oCN9iA7y4Pc
e30pNZhQbh1iExYrVS4N9a2McfZ3JEjNZn1JjY5jm1qGaLkLGyoPbIpqjvsCgYEA
uPQbuvXsSTqDN4a65uvvLam5WW9GhKzZ2J0+B18SE6BKop3E6vwKwWYrwBps+xLN
e392F1zzyrFrCx7YJxX9k/THyAAHuwXbm49P4DmFsMujUpc7YMFY6TeKZkxvt8AH
88MdRWZuwbYB4kSx+svffAvFwwT8wrUTkLCt/TTmL+8CgYBUaIDeYqiP3W9tfU2U
Lir2WLe/cgAxvVBL212g3e31BcKrxHBExeuHuOEy4f7Ql/dzbQ3n4ucSQqSf0Z15
6ZwRPl1tbfuxyD/Bv3ziBRi3V+BECwYy765N7ZcK8o88e1vHjFNRi/8jPIoHabc7
G42PodwfD3xUQKONThkgCHvF4A==
-----END PRIVATE KEY-----
END
)

confFileTemplate="[ req ]
default_bits = 2048
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = HOSTNAME (HOSTNAME)
CN_default = HOSTNAME
O = Example Company (Ericsson AB)
O_default = Ericsson AB
OU = Example Unit (IT)
OU_default = IT
L = City (Stockholm)
L_default = Stockholm
ST = State (Stockholm)
ST_default = Stockholm
C = Country (SE)
C_default = SE

[ req_ext ]
subjectAltName = DNS: HOSTNAME"

function INFO() {
  echo "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [$FUNCNAME]: $1"
}

function ERROR() {
  RED='\033[1;31m'
  NC='\033[0m'
  echo -e "[$(date +%Y-%m-%d' '%T,%3N)] [$0] [${RED}$FUNCNAME${NC}]: $1"
  exit 1
}

function NOTIFY() {
  GREEN='\033[1;32m'
  NC='\033[0m'
  printf "\n${GREEN}%s\n${NC}" "$1"
}

if [ -z "$CLUSTER_NOTIFY" ]; then
  NOTIFY "Current cluster: $CLUSTER"
  CLUSTER_NOTIFY="done"
fi

function selfSignedCerts() {
  set +x
  INFO "Creating self-signed certificates"
  mkdir -p $WORKING_DIR
  echo "$SELF_SIGN_KEY_TLP" > $SELF_SIGN_KEY
  echo "$SELF_SIGN_CRT_TLP" > $SELF_SIGN_CRT
  createConfFilesForEGAD
  for each in "${hosts[@]}"; do
    INFO "Creating self-signed certificates for $each"
    set +x
    openssl x509 -req -in $WORKING_DIR/$each.csr -out $WORKING_DIR/$each.crt -CA $SELF_SIGN_CRT -CAkey $SELF_SIGN_KEY -CAcreateserial -extfile $WORKING_DIR/$each.conf -extensions req_ext -days 10950
    rm -f $WORKING_DIR/$each.csr
    rm -f $WORKING_DIR/$each.conf
  done
}

function createConfFilesForEGAD() {
  mkdir -p $WORKING_DIR
  echo "$confFileTemplate" > $WORKING_DIR/confFileTemplate.conf
  for each in "${hosts[@]}"; do
    INFO "Creating config file for $each"
    sed "s/HOSTNAME/${each}/g" $WORKING_DIR/confFileTemplate.conf >$WORKING_DIR/$each.conf
    createConfFile $each
  done
  rm -f $WORKING_DIR/confFileTemplate.conf
}

function createConfFile() {
  mkdir -p $WORKING_DIR
  openssl req -new -out $WORKING_DIR/$1.csr -keyout $WORKING_DIR/$1.key -config $WORKING_DIR/$1.conf -batch -nodes
}

function createNamespace() {
  if ! (kubectl get namespace | grep $NAMESPACE > /dev/null); then
    i=0
    while ! (kubectl get namespace | grep $NAMESPACE > /dev/null)
      do
        if ! (kubectl get namespace --no-headers -o custom-columns=":metadata.labels.envName" | grep vnfm$i > /dev/null); then
          kubectl create namespace $NAMESPACE
          kubectl label namespace $NAMESPACE envOwner=$SIGNUM envName=vnfm$i
        else
          ((i=i+1))
        fi
      done
  else
    INFO "Namespace $NAMESPACE already exists and labeled with $SIGNUM"
  fi
}

function createServiceAccount() {
  INFO "Checking if ServiceAccount exists"
  kubectl get ServiceAccount -n $NAMESPACE | grep 'evnfm'
  if [[ $? == 1 ]]; then
    INFO "Creating ServiceAccount evnfm"
    cat <<EOF | kubectl apply -n $NAMESPACE -f -
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: evnfm
      automountServiceAccountToken: true
EOF
  else
    INFO "ServiceAccount already exists"
  fi
}

function createClusterRoleBinding() {
  INFO "Checking if ClusterRoleBinding exists"
  kubectl get clusterRoleBinding | grep "evnfm-${NAMESPACE}"
  if [[ $? == 1 ]]; then
    INFO "Creating ClusterRoleBinding evnfm-${NAMESPACE}"
    cat <<EOF | kubectl apply -n $NAMESPACE -f -
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: evnfm-$NAMESPACE
      subjects:
        - kind: ServiceAccount
          name: evnfm
          namespace: $NAMESPACE
      roleRef:
        kind: ClusterRole
        name: cluster-admin
        apiGroup: rbac.authorization.k8s.io
EOF
  else
    INFO "ClusterRoleBinding already exists"
  fi
}

function createDockerRegSecret() {
  INFO "Checking if container-registry-users-secret secret exists"
  kubectl get secret -n $NAMESPACE | grep "container-registry-users-secret"
  if [[ $? == 1 ]]; then
    INFO "Creating container-registry-users-secret secret"
    htpasswd -cBb htpasswd $REGISTRY_CREDENTIALS_USER $REGISTRY_CREDENTIALS_PASS
    kubectl create secret generic container-registry-users-secret --from-file=htpasswd=./htpasswd --namespace $NAMESPACE
    rm -f ./htpasswd
  else
    INFO "container-registry-users-secret secret already exists"
  fi
}

function createDockerRegCredentialsSecret() {
  INFO "Checking if container-credentials secret exists"
  kubectl get secret -n $NAMESPACE | grep "container-credentials"
  if [[ $? == 1 ]]; then
    INFO "Creating container-credentials secret"
    kubectl create secret generic container-credentials --from-literal=url=$HOST_DOC_REG --from-literal=userid=$REGISTRY_CREDENTIALS_USER \
      --from-literal=userpasswd=$REGISTRY_CREDENTIALS_PASS --namespace $NAMESPACE
  else
    INFO "container-credentials secret already exists"
  fi
}

function createSecAccessMgmtCredsSecret() {
  INFO "Checking if eric-sec-access-mgmt-creds secret exists"
  kubectl get secret -n $NAMESPACE | grep "eric-sec-access-mgmt-creds"
  if [[ $? == 1 ]]; then
    INFO "Creating eric-sec-access-mgmt-creds secret"
    kubectl create secret generic eric-sec-access-mgmt-creds --from-literal=kcadminid=admin --from-literal=kcpasswd=$PASSWORD \
      --from-literal=pguserid=admin --from-literal=pgpasswd=test-pw --namespace $NAMESPACE
  else
    INFO "eric-sec-access-mgmt-creds secret already exists"
  fi
}

function createPostgressDbSecret() {
  INFO "Checking if eric-eo-database-pg-secret secret exists"
  kubectl get secret -n $NAMESPACE | grep "eric-eo-database-pg-secret"
  if [[ $? == 1 ]]; then
    INFO "Creating eric-eo-database-pg-secret secret"
    kubectl create secret generic eric-eo-database-pg-secret --from-literal=custom-user=eo_user --from-literal=custom-pwd=postgres \
      --from-literal=super-user=postgres --from-literal=super-pwd=postgres --from-literal=metrics-user=exporter --from-literal=metrics-pwd=postgres \
      --from-literal=replica-user=replica --from-literal=replica-pwd=postgres --namespace $NAMESPACE
  else
    INFO "eric-eo-database-pg-secret secret already exists"
  fi
}

function createDockerRegistryAccessSecret() {
  INFO "Logging to dockerhubs"
  docker --config $WORKING_DIR login selndocker.mo.sw.ericsson.se -u $GERRIT_USERNAME -p "$GERRIT_PASSWORD"
  docker --config $WORKING_DIR login armdocker.rnd.ericsson.se -u $GERRIT_USERNAME -p "$GERRIT_PASSWORD"
  docker --config $WORKING_DIR login serodocker.sero.gic.ericsson.se -u $GERRIT_USERNAME -p "$GERRIT_PASSWORD"
  INFO "Creating k8s-registry-secret secret"
  kubectl create secret generic k8s-registry-secret \
    --from-file=.dockerconfigjson=$WORKING_DIR/config.json \
    --type=kubernetes.io/dockerconfigjson \
    --namespace $NAMESPACE
  rm -rf $WORKING_DIR/config.json
}

function createTlsSecret() {
  INFO "Checking if $1 secret exists"
  kubectl get secret $1 -n $NAMESPACE
  if [[ $? == 1 ]]; then
    INFO "Creating $1 secret"
    kubectl create secret tls $1 --key $WORKING_DIR/$2.key --cert $WORKING_DIR/$2.crt -n $NAMESPACE
  else
    INFO "$1 secret already exists"
  fi
}

function createAllTlsSecrets() {
  createTlsSecret registry-tls-secret $HOST_DOC_REG
  createTlsSecret helm-registry-tls-secret $HOST_HELM_REG
  createTlsSecret iam-tls-secret $HOST_IDAM
  createTlsSecret vnfm-tls-secret $HOST_VNFM
  createTlsSecret gas-tls-secret $HOST_GAS
  createTlsSecret gr-tls-secret $HOST_GR
}

function createCaCertsSecret() {
  INFO "Checking if iam-cacert-secret secret exists"
  kubectl get secret -n $NAMESPACE | grep "iam-cacert-secret"
  if [[ $? == 1 ]]; then
    INFO "Creating iam-cacert-secret secret"
    cp $SELF_SIGN_CRT $WORKING_DIR/tls.crt
    cp $SELF_SIGN_CRT $WORKING_DIR/cacertbundle.pem
    kubectl create secret generic iam-cacert-secret --from-file=$WORKING_DIR/tls.crt --from-file=$WORKING_DIR/cacertbundle.pem --namespace $NAMESPACE
    rm -f $WORKING_DIR/tls.crt
    rm -f $WORKING_DIR/cacertbundle.pem
  else
    INFO "iam-cacert-secret secret already exists"
  fi
}

function createEnmSecret() {
  INFO "Checking if enm-secret secret exists"
  kubectl get secret -n $NAMESPACE | grep "enm-secret"
  if [[ $? == 1 ]]; then
    local scriptingIp=$(kubectl get svc --namespace $ENM_NAMESPACE | awk '/enm/ {print $4}')
    INFO "Creating enm-secret secret"
    kubectl create secret generic enm-secret \
    --from-literal=enm-scripting-ip=$scriptingIp \
    --from-literal=enm-scripting-username=enm \
    --from-literal=enm-scripting-password=enm123! \
    --from-literal=enm-scripting-connection-timeout=20000 \
    --from-literal=enm-scripting-ssh-port=22 \
    --namespace $NAMESPACE
  else
    INFO "enm-secret secret already exists"
  fi
}

function prepareNamespace() {
  INFO "Preparing namespace and pre-requisites"
  createNamespace
  source $0
  selfSignedCerts
  createDockerRegSecret
  createDockerRegistryAccessSecret
  createDockerRegCredentialsSecret
  createSecAccessMgmtCredsSecret
  createPostgressDbSecret
  createAllTlsSecrets
  createCaCertsSecret
}

function prepareEGAD() {
  if kubectl get ns | grep $NAMESPACE  > /dev/null; then
    mkdir -p $WORKING_DIR
    INFO "Preparing config files for EGAD certificates generation"
    createConfFilesForEGAD
    exit 0
  else
    ERROR "Run -p or --prepare step first!"
  fi
}

function rundos2unixCommand() {
  INFO "Running rundos2unixCommand command on all.crt files in the working directory"
  dos2unix $(ls $WORKING_DIR/*.crt)
}

function bundleEgadCerts() {
  INFO "Creating bundles for EGAD certificates"
  egad_issuing_cert="EGADIssuingCA3.crt"
  egad_root_cert="EGADRootCA.crt"
  if [[ ! -f $egad_issuing_cert ]]; then
    INFO "Please put EGADIssuingCA3.crt certificate in the current directory"
    exit 1
  fi
  if [[ ! -f $egad_root_cert ]]; then
    INFO "Please put EGADRootCA.crt certificate in the current directory"
    exit 1
  fi
  for each in "${hosts[@]}"; do
    cert_file="$WORKING_DIR/$each.crt"
    if [[ -f $cert_file ]]; then
      INFO "Bundling certificate for $each"
      cat $egad_issuing_cert >> $WORKING_DIR/$each.crt
      cat $egad_root_cert >> $WORKING_DIR/$each.crt
    else
      INFO "Certificate file $cert_file cannot be found - skipping bundling"
    fi
  done
  cat $egad_issuing_cert >> $WORKING_DIR/intermediate-ca.crt
  cat $egad_root_cert >> $WORKING_DIR/intermediate-ca.crt
}

function spitValuesFile() {
  INFO "Rendering site_values.yaml file"
  renderValues
  echo "$values_yaml" > $WORKING_DIR/site_values_$HELMFILE_CHART.yaml
}

function spitOptionalityFile() {
  INFO "Rendering optionality.yaml file"
  renderOptionality
  echo "$optionality_yaml" > $WORKING_DIR/eric-eo-helmfile/optionality.yaml
}

function spitOldValuesFile() {
  INFO "Creating values.yaml file"
  echo "$old_values_yaml" > $WORKING_DIR/values.yaml
}

function outputCertificateRequests() {
  INFO "Printing all generated certificate requests *.crt files in the working directory"
  cat $WORKING_DIR/*.csr
  echo """
  ##############################################################################################################

      Visit https://certificateservices.internal.ericsson.com to sign printed certificate requests

      alternative email = PDLERTIFIC@pdl.internal.ericsson.com
      server type       = Red Hat
      signing algorithm = sha256 with RSAEncryption SHA256 Root
      certificate type  = INTERNAL TRUST (never create external trust certificates)

      Store signed certificates in $WORKING_DIR as <hostname>.crt files

  ##############################################################################################################
  """
}

function runInstallCommand() {
  INFO "Saving values.yaml file"
  spitOldValuesFile
  createServiceAccount
  createClusterRoleBinding
  INFO "Adding and updating helm repo"
  helm repo add proj-eo-helm $ARTIFACTORY_PATH/proj-eo-helm/
  helm repo up
  INFO "Running install command"
  command="helm --debug install $HELM_RELEASENAME $HELM_CHART --namespace $NAMESPACE --values $WORKING_DIR/$VALUES_FILE --wait --timeout 15m --devel"
  # command="helm2 install $HELM_CHART --namespace $NAMESPACE --values $WORKING_DIR/$VALUES_FILE  --name $HELM_RELEASENAME"
  INFO "Install command: $command"
  eval $command
}

function getHelmfileLatestVersion() {
  latestVersion=$(curl -u "${GERRIT_USERNAME}:${GERRIT_PASSWORD}" -X POST $ARTIFACTORY_PATH/api/search/aql \
    -H "content-type: text/plain" \
    -d 'items.find({ "repo": {"$eq":"proj-eo-helm"}, "path": {"$match" : "eric-eo-helmfile"}}).sort({"$desc": ["created"]}).limit(1)' \
      2>/dev/null | grep name | sed 's/.*eric-eo-helmfile-\(.*\).tgz.*/\1/')
  echo "$latestVersion"
}

function downloadHelmfileChart() {
  INFO "Removing previous Helmfile chart"
  rm -rf $WORKING_DIR/eric-eo-helmfile
  INFO "Checking Helmfile source"
    if [[ $HELMFILE_CHART_PATH == http* ]]; then
      INFO "Helmfile chart path is: $HELMFILE_CHART_PATH"
      INFO "Downloading helmfile chart archive to $WORKING_DIR"
      wget -nvc $HELMFILE_CHART_PATH/eric-eo-helmfile-$HELMFILE_CHART.tgz -P $WORKING_DIR
      INFO "Unpacking helmfile chart archive in $WORKING_DIR"
      tar -xf $WORKING_DIR/eric-eo-helmfile-$HELMFILE_CHART.tgz -C $WORKING_DIR
      INFO "Removing helmfile chart archive"
      rm -rf $WORKING_DIR/eric-eo-helmfile-$HELMFILE_CHART.tgz
    else
      HELMFILE_CHART_DIR=$HELMFILE_CHART_PATH/$HELMFILE_CHART
      INFO "Helmfile chart path is: $HELMFILE_CHART_DIR"
      INFO "Copying helmfile chart from local path to $WORKING_DIR"
      mkdir -p $WORKING_DIR/eric-eo-helmfile
      cp -r $HELMFILE_CHART_DIR/eric-eo-helmfile/* $WORKING_DIR/eric-eo-helmfile
    fi
}

function sortVersions() {
  [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

function compareVersions() {
  [ "$1" = "$2" ] && return 1 || sortVersions $1 $2
}

function deployClusterRole() {
  INFO "Creating ClusterRole for release before $CLUSTER_ROLE_HELMFILE"
  createServiceAccount
  createClusterRoleBinding
}

function cleanNelsParams() {
  NELS_LICENSING_CLOUD_NATIVE_TEMPLATE=$(cat <<END
  eric-lm-combined-server:
    licenseServerClient:
      licenseServer:
        thrift:
          host: ''
END
)
  NELS_LICENSING_GLOBAL_TEMPLATE=''
  NELS_LATEST_LICENSING_GLOBAL_TEMPLATE=''
  NELS_LATEST_LICENSING_CLOUD_NATIVE_TEMPLATE=''
}

function cleanNelsOldParams() {
  NELS_LICENSING_CLOUD_NATIVE_TEMPLATE=''
  NELS_LICENSING_GLOBAL_TEMPLATE=''
}

function cleanNelsNewParams() {
  NELS_LATEST_LICENSING_CLOUD_NATIVE_TEMPLATE=''
  NELS_LATEST_LICENSING_GLOBAL_TEMPLATE=''
}

function cleanICCRParams() {
  unset ICCR_GLOBAL_TEMPLATE
  unset ICCR_SEC_ACCESS_TEMPLATE
# We should leave this for some time to keep compatibility for 2.19.0-166 - 2.20.0-28 EO versions
ICCR_CNCS_TEMPLATE=$(cat <<END
  eric-tm-ingress-controller-cr:
    enabled: false
END
)
}

function isSnapshot() {
  hash=$( cut -d "-" -f3 <<< $versionHelmfile)
  if [[ ${#hash} == 8 ]]; then
    HELMFILE_CHART_PATH=$HELMFILE_CHART_PATH_SNAPSHOT
  else
    HELMFILE_CHART_PATH=$HELMFILE_CHART_PATH_RELEASE
  fi
}

function cleanSMParams() {
  unset SM_CNCS_TEMPLATE
}

function cleanGrParams() {
  unset GR_TEMPLATE
}

function cleanupContainerRegistryParams() {
  unset CONTAINER_REGISTRY_TEMPLATE
}

function populateEnmSecretName() {
  EnmSecretNameValue="enm-secret"
}

function helmfilePreSteps() {
  HELMFILE_CHART=$versionHelmfile
  INFO "Helmfile version for deployment: $HELMFILE_CHART"
  INFO "Checking if deployment with ClusterRole"
  compareVersions $HELMFILE_CHART $CLUSTER_ROLE_HELMFILE && deployClusterRole ||  INFO "Deployment without ClusterRole"
  INFO "Saving values.yaml file"
  SM_ENABLED=$(compareVersions $HELMFILE_CHART $SM_HELMFILE && echo 'false' || echo 'true')
  NELS_ENABLED=$(compareVersions $HELMFILE_CHART $NELS_HELMFILE && echo 'false' || echo 'true')
  NELS_LATEST_ENABLED=$(compareVersions $HELMFILE_CHART $NELS_LATEST_VALUES && echo 'false' || echo 'true')
  if [ $NELS_ENABLED = 'true' ]; then
    if [ $NELS_LATEST_ENABLED = 'true' ]; then
      INFO "New NeLS is enabled"
      cleanNelsOldParams
    else
      INFO "NeLS is enabled"
      cleanNelsNewParams
    fi
  else
    INFO "NeLS is disabled"
    cleanNelsParams
  fi
  if [ $SM_ENABLED = 'true' ]; then
    INFO "ServiceMesh based deploy is enabled"
    ICCR_ENABLED=false
    cleanICCRParams
  else
    INFO "ICCR based deploy is enabled"
    ICCR_ENABLED=true
    cleanSMParams
  fi
  if [ $ENM_STUB_ENABLED = 'true' ]; then
    INFO "ENM stub is enabled"
    populateEnmSecretName
    runInstallEnmStub
  else
    INFO "ENM stub is disabled"
  fi
  if [ $GR_ENABLED = 'true' ]; then
    INFO "Geo Redundancy is enabled"
    CONTAINER_REGISTRY_ENABLED=true
    BRO_ENABLED=true
  else
    INFO "Geo Redundancy is disabled"
    cleanGrParams
  fi
  if [ $CONTAINER_REGISTRY_ENABLED = 'true' ]; then
    INFO "Container Registry is enabled"
  else
    INFO "Container Registry is disabled"
    cleanupContainerRegistryParams
  fi
  spitValuesFile
  INFO "Preparing helmfile working directory"
  isSnapshot
  downloadHelmfileChart
  INFO "Saving optionality.yaml file"
  spitOptionalityFile
}

function runInstallHelmfileCommand() {
  INFO "Running install helmfile command"
  command="helmfile --file $WORKING_DIR/eric-eo-helmfile/helmfile.yaml --state-values-file $PWD/$WORKING_DIR/site_values_$HELMFILE_CHART.yaml \
    --state-values-set helmfile.app.namespace=$NAMESPACE --state-values-set helmfile.crd.namespace=$CRD_NAMESPACE apply --suppress-diff"
  INFO "Install command: $command"
  eval $command
}

function get_enm_lb_ip() {
    kube_lb_ip=$(kubectl get svc  -A -o custom-columns=":spec.loadBalancerIP" | grep -v  "<none>")
    for j in $ENM_LB_IPS;
    do
      for i in $kube_lb_ip;
          do
              if [[ "$i" == "$j" ]]; then
                    ENM_LB_IPS=${ENM_LB_IPS//$j}
                  break
              fi
      done
    done
    if [ ! $(echo $ENM_LB_IPS| cut -d " " -f1) == "" ]; then
      echo  $(echo $ENM_LB_IPS| cut -d " " -f1)
    else
      exit 1
    fi
}

function runInstallEnmStub() {
  kubectl create namespace $ENM_NAMESPACE
  ENM_LB_IP=$(get_enm_lb_ip)
  if [[ $? == 1 ]]; then
    ERROR "ENM STUB does not have IP"
    exit 1
  fi
  INFO "ENM IP - $ENM_LB_IP"
  kubectl label namespace $ENM_NAMESPACE envOwner=$SIGNUM envEnmName=$NAMESPACE
  INFO "Running install ENM command"
  helm repo add cvnfm-enm-cli-stub https://arm.seli.gic.ericsson.se/artifactory/proj-eo-evnfm-helm
  helm repo update
  helm fetch cvnfm-enm-cli-stub/cvnfm-enm-cli-stub --devel
  command="helm install --atomic cvnfm-enm-cli-stub cvnfm-enm-cli-stub*.tgz --wait --debug --namespace $ENM_NAMESPACE --set service.loadBalancerIP=$ENM_LB_IP"
  INFO "Install ENM command: $command"
  eval $command
  rm -rf cvnfm-enm-cli-stub*.tgz
  createEnmSecret
}

function runUpgradeHelmfileCommand() {
  cd $WORKING_DIR
  INFO "Checking helm-migrator existence. Helm-migrator version is:"
  helm-migrator version
  if [[ $? == 1 ]]; then
    ERROR "helm-migrator is not exists in PATH or chmod is not 755. Please, download it from $HELM_MIGRATOR_PATH or change access"
  else
    INFO "Running helm-migrator migrate command"
    command="helm-migrator helmfile migrate --namespace $NAMESPACE --helm-binary-path helm --kubeconfig ~/.kube/config \
      --helmfile-yaml-path eric-eo-helmfile/helmfile.yaml --state-values-file $PWD/site_values_$HELMFILE_CHART.yaml --verbosity 3"
    INFO "Migrate command: $command"
    eval $command
    cd ../..
    if [[ $? == 0 ]]; then
      runInstallHelmfileCommand
    else
      ERROR "helm-migrator migrate command were unsuccessful"
    fi
  fi
}

function runUpgradeCommand() {
  INFO "Saving values.yaml file"
  spitValuesFile
  INFO "Adding and updating helm repo"
  helm repo add proj-eo-helm $ARTIFACTORY_PATH/proj-eo-helm/
  helm repo up
  INFO "Running upgrade command"
  command="helm --debug upgrade $HELM_RELEASENAME $HELM_CHART --namespace $NAMESPACE --values $WORKING_DIR/$VALUES_FILE --wait --timeout 15m --devel"
  INFO "Install command: $command"
  eval $command
}

function runCleanUp() {
  INFO "Checking if namespace $NAMESPACE exists"
  kubectl get namespaces | grep $NAMESPACE
  if [[ $? == 0 ]]; then
    INFO "Running uninstall command"
    for each in $(helm ls -qn $NAMESPACE); do
      INFO "Uninstall release: $each";
      helm uninstall $each -n $NAMESPACE;
    done
    INFO "Deleting namespace $NAMESPACE"
    kubectl delete ns $NAMESPACE
  else
    INFO "Namespace $NAMESPACE not found, nothing to delete"
  fi
  INFO "Checking if namespace $ENM_NAMESPACE exists"
    kubectl get namespaces | grep $ENM_NAMESPACE
    if [[ $? == 0 ]]; then
      INFO "Running uninstall command"
      for each in $(helm ls -qn $ENM_NAMESPACE); do
        INFO "Uninstall release: $each";
        helm uninstall $each -n $ENM_NAMESPACE;
      done
      INFO "Deleting namespace $ENM_NAMESPACE"
      kubectl delete ns $ENM_NAMESPACE
    else
      INFO "Namespace $ENM_NAMESPACE not found, nothing to delete"
    fi
  INFO "Checking if ClusterRoleBinding exists"
  kubectl get ClusterRoleBinding -n $NAMESPACE | grep "evnfm-${NAMESPACE}"
  if [[ $? == 0 ]]; then
    kubectl delete clusterrolebinding evnfm-$NAMESPACE
  else
    INFO "ClusterRoleBinding doesn't exist"
  fi
  INFO "Checking if ClusterRole exists"
  kubectl get clusterrole | grep $SIGNUM
  if [[ $? == 0 ]]; then
    for each in $(kubectl get clusterrole -l app.kubernetes.io/instance=$SIGNUM-eric-eo-evnfm -o name); do
      kubectl delete $each;
    done
  else
    INFO "ClusterRole doesn't exist"
  fi
}

# use this only once - fixes x509 error when accessing docker registry (e.g. at first time installation)
function addCAToLocalTrustStore() {
  INFO "Adding common CA to trust store"
  echo "$SELF_SIGN_CRT_TLP" > /tmp/CA_EVNFM.crt
  sudo cp /tmp/CA_EVNFM.crt /usr/local/share/ca-certificates/
  if [[ -f /usr/local/share/ca-certificates/CA_EVNFM.crt ]]; then
    sudo update-ca-certificates
    sudo systemctl restart docker
    sudo systemctl restart containerd.service
    if [[ ! -f /etc/ssl/certs/CA_EVNFM.pem ]]; then
      ERROR "CA certificate was not added"
    fi
  else
    ERROR "Please check that you can run sudo"
  fi
}

function addLabelForNoCleanup() {
  INFO "Checking if namespace label exists"
  kubectl get namespace --show-labels $NAMESPACE | grep doNotCleanup=true
  if [[ $? == 0 ]]; then
    INFO "Namespace is already labeled"
  else
    INFO "Adding namespace label"
    kubectl label namespace $NAMESPACE doNotCleanup=true
  fi
}

function installPackageCertificates() {
  INFO "Copying certificates for signed packages from evnfm-testing-artifacts repository HEAD"
  TRUSTED_DIR="certificates/trusted"
  mkdir -p $WORKING_DIR/$TRUSTED_DIR
  wget --user $GERRIT_USERNAME --password "$GERRIT_PASSWORD" $SIGNED_CERTS_REPO/$SIGNED_CERTS_PATH%2FIntermediate-CA-1.crt/content
  cat content | base64 -d > $WORKING_DIR/$TRUSTED_DIR/intermediate.pem
  rm -rf content
  wget --user $GERRIT_USERNAME --password "$GERRIT_PASSWORD" $SIGNED_CERTS_REPO/$SIGNED_CERTS_PATH%2Froot-ca.cert/content
  cat content | base64 -d > $WORKING_DIR/$TRUSTED_DIR/root.pem
  rm -rf content
  wget --user $GERRIT_USERNAME --password "$GERRIT_PASSWORD" $SIGNED_CERTS_REPO/$SIGNED_CERTS_PATH%2Fsigning-ca.cert/content
  cat content | base64 -d > $WORKING_DIR/$TRUSTED_DIR/signing.pem
  rm -rf content
  INFO "Saving certm script from am-integration-charts repository HEAD"
  wget --user $GERRIT_USERNAME --password "$GERRIT_PASSWORD" $EVNFM_CHART_REPO/branches/master/files/Scripts%2Feo-evnfm%2Fcertificate_management.py/content
  cat content | base64 -d > $WORKING_DIR/certificate_management.py
  rm -rf content
  cp $WORKING_DIR/intermediate-ca.crt $WORKING_DIR/certificates/
  INFO "Installing certificates for signed packages"
  cd $WORKING_DIR
  command="python3 certificate_management.py install-certificates"
  INFO "Command to evaluate: $command"
  eval $command
}

function cleanPostgresDatabase() {
  INFO "Getting postgres database master pod"
  master=$(kubectl get pods --selector role=master -n $NAMESPACE | awk '/application-manager/ {print$1}')
  INFO "Cleaning orchestrator service database"
  kubectl exec -ti $master -c application-manager-postgres -n $NAMESPACE -- psql -d orchestrator -U postgres \
    -c 'truncate app_vnf_instance cascade;' \
    -c 'truncate cluster_config_instances;' \
    -c 'truncate app_cluster_config_file;' \
    -c 'truncate vnfinstance_namespace_details;'
  INFO "Cleaning onboarding service database"
  kubectl exec -ti $master -c application-manager-postgres -n $NAMESPACE -- psql -d onboarding -U postgres \
    -c 'truncate app_packages cascade;' \
    -c 'truncate charts cascade;'
}

function showHelp() {
  echo "Usage: $0 [option...]" >&2
  echo """
  ############################################################################################################################################

     --chart /path/to/chart,            Define helm chart on device, otherwise latest will be used
     -n    | --namespace <namespace>    Define namespace, otherwise '$SIGNUM-ns' will be used
     -e    | --egad,                    Create files necessary to create EGAD certs
     -d    | --rundos2unixCommand,      Run rundos2unixCommand command on all .crt files in the working directory
     -b    | --bundleEgadCerts,         Create bundles for EGAD certificates
     -p    | --prepare,                 Prepare for install i.e. create namespace, service account, clusterRoleBindings
     -o    | --installold,              Run install command for helm chart (obsoleted)
     -a    | --upgradeold,              Run upgrade command for helm chart (obsoleted)
     -i    | --install <version>,       Run install command of <version> helmfile chart
     -u    | --upgrade <version>,       Run upgrade command to <version> helmfile chart (helm-migrator binary should exist in PATH)
     -c    | --cleanup,                 Delete namespace and ClusterRoles/ClusterRoleBindings
     --co  | --certoutput,              Print content of all generated certificate requests *.csr files
     -t    | --no-cleanup,              Label namespace to skip night clean up. Only for important work - cluster resources are limited!
     -l    | --localca,                 Add CA to a local trust store. Required Root access, please run with sudo (only once)
     -w    | --cleandb                  Run clean up command for postgres database
     --ipc                              Install packages certificates for signed packages (remove redundant site_values yamls first!)
     -h    | --help                     Show help message

     Note: Script handles arguments from left to right (e.g. 'sh $0 -cpti' will clean, prepare, label namespace
             and deploy latest helmfile version), so arrange them correctly

     FYI: We merged steps '-s' and '-p'. No need to run '-s', please proceed with '-p' only!

  ############################################################################################################################################
  """
  exit 1
}

if ! TEMP=$(getopt -o e,d,b,p,o,a,i,t,u,c,g,n:,l,w,h,* \
  -l cu,co,egad,namespace:,rundos2unixCommand,bundleEgadCerts,prepare,installold,upgradeold,install,upgrade,cleanup,certoutput,chart:,no-cleanup,localca,cleandb,ipc,help,* -q -- "$@"); then
  showHelp
  exit 1
fi

eval set -- "$TEMP"
while true; do
  case "$1" in
  --chart)
    HELM_CHART="$2"
    shift 2
    ;;
  -n | --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  -e | --egad)
    prepareEGAD
    shift 1
    ;;
  -d | --rundos2unixCommand)
    rundos2unixCommand
    shift 1
    ;;
  -b | --bundleEgadCerts)
    bundleEgadCerts
    shift 1
    ;;
  -p | --prepare)
    prepareNamespace
    shift 1
    ;;
  -i | --install)
    versionHelmfile=${*: -1}
    if [[ $versionHelmfile == "--" ]]; then
      versionHelmfile=$(getHelmfileLatestVersion)
    fi
    helmfilePreSteps
    runInstallHelmfileCommand
    shift 1
    ;;
  -u | --upgrade)
    versionHelmfile=${*: -1}
    if [[ $versionHelmfile == "--" ]]; then
      versionHelmfile=$(getHelmfileLatestVersion)
    fi
    helmfilePreSteps
    runUpgradeHelmfileCommand
    shift 1
    ;;
  -o | --installold)
    runInstallCommand
    shift 1
    ;;
  -a | --upgradeold)
    runUpgradeCommand
    shift 1
    ;;
  -c | --cleanup)
    runCleanUp
    shift 1
    ;;
  --co | --certouput)
    outputCertificateRequests
    shift 1
    ;;
  -t | --no-cleanup)
    addLabelForNoCleanup
    shift 1
    ;;
  -l | --localca)
    addCAToLocalTrustStore
    shift 1
    ;;
  -w | --cleandb)
    cleanPostgresDatabase
    shift 1
    ;;
  --ipc)
    installPackageCertificates
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
