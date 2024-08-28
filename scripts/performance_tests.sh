#!/usr/bin/env bash

function log_info() {
    echo "[INFO]: $1"
}

kube_config=`echo $KUBE_CONFIG_PATH`
log_info "Kubernetes config path is: $kube_config"
namespace="$NS"
log_info "Namespace is: $namespace"

eric_eo_evnfm_nbi_iccr=`kubectl -n $namespace get httpproxy --kubeconfig=$kube_config | awk '/^eric-eo-evnfm-nbi-iccr/ {print$1}'`
gateway=`kubectl -n $namespace get httpproxy $eric_eo_evnfm_nbi_iccr -o jsonpath="{.spec.virtualhost.fqdn}" --kubeconfig=$kube_config`
log_info "Gateway host is: $gateway"

username=`kubectl -n $namespace get secret eric-evnfm-rbac-default-user -o jsonpath='{.data.userid}' --kubeconfig=$kube_config | base64 --decode`
log_info "Username is: $username"

password=`kubectl -n $namespace get secret eric-evnfm-rbac-default-user -o jsonpath='{.data.userpasswd}' --kubeconfig=$kube_config | base64 --decode`
log_info "Password is: $password"

sed -i "s/host=.*/host=$gateway/g" eric-eo-evnfm-acceptance-testware-performance/src/test/jmeter/configuration/global.properties | sed -e "s/username=.*/username=$username/g" | sed -e "s/password=.*/password=$password/g"

log_info "Config of global.properties for Performance tests execution is:"
sed -n '17,19p' global.properties

exit 0