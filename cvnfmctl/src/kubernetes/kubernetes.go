package kubernetes

import (
	"context"
	"cvnfmctl/constant"
	"cvnfmctl/model"
	"gopkg.in/yaml.v3"
	v12 "k8s.io/api/core/v1"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"os"
	"regexp"
	"strings"
)

type K8sClientSet struct {
	ctx        context.Context
	namespace  string
	kubeClient *kubernetes.Clientset
}

func NewK8sClientSet(ctx context.Context, configFilePath, namespace string) (*K8sClientSet, error) {
	kc, err := getKubeClient(configFilePath)

	if err != nil {
		return nil, err
	}

	return &K8sClientSet{
		ctx,
		namespace,
		kc,
	}, nil
}

func (kcs *K8sClientSet) GetStrategy(namespace string) (map[string]interface{}, error) {
	dps, err := kcs.kubeClient.AppsV1().Deployments(namespace).List(kcs.ctx, v1.ListOptions{})

	if err != nil {
		return nil, err
	}

	deployments := make(map[string]interface{})
	for _, d := range dps.Items {
		deployments[d.Name] = d.Spec.Strategy.RollingUpdate
	}

	return deployments, nil
}

func (kcs *K8sClientSet) GetKubeControllers() (*model.Resources, error) {
	deployments, err := getDeployments(kcs.ctx, kcs.kubeClient, kcs.namespace)

	if err != nil {
		return nil, err
	}

	statefulSets, err := getStatefulSets(kcs.ctx, kcs.kubeClient, kcs.namespace)

	if err != nil {
		return nil, err
	}

	daemonSets, err := getDaemonSets(kcs.ctx, kcs.kubeClient, kcs.namespace)

	if err != nil {
		return nil, err
	}

	return &model.Resources{
		Deployments:  deployments,
		StatefulSets: statefulSets,
		DaemonSets:   daemonSets,
	}, nil
}

func getDeployments(ctx context.Context, kc *kubernetes.Clientset, namespace string) (map[string]model.Deployment, error) {
	dps, err := kc.AppsV1().Deployments(namespace).List(ctx, v1.ListOptions{})

	if err != nil {
		return nil, err
	}

	deployments := make(map[string]model.Deployment)
	for _, d := range dps.Items {
		deployments[d.Name] = model.Deployment{BaseResource: model.BaseResource{Name: d.Name}}
	}

	return deployments, nil
}

func getStatefulSets(ctx context.Context, kc *kubernetes.Clientset, namespace string) (map[string]model.StatefulSet, error) {
	sts, err := kc.AppsV1().StatefulSets(namespace).List(ctx, v1.ListOptions{})

	if err != nil {
		return nil, err
	}

	statefulSets := make(map[string]model.StatefulSet)

	for _, s := range sts.Items {
		pvc := s.Spec.VolumeClaimTemplates != nil && len(s.Spec.VolumeClaimTemplates) > 0
		db := isDataBase(s.Name)
		st := model.StatefulSet{BaseResource: model.BaseResource{Name: s.Name}, PVC: pvc, DB: db}
		statefulSets[s.Name] = st
	}

	return statefulSets, nil
}

func getDaemonSets(ctx context.Context, kc *kubernetes.Clientset, namespace string) (map[string]model.DaemonSets, error) {
	dss, err := kc.AppsV1().DaemonSets(namespace).List(ctx, v1.ListOptions{})

	if err != nil {
		return nil, err
	}

	daemonSets := make(map[string]model.DaemonSets)

	for _, ds := range dss.Items {
		daemonSets[ds.Name] = model.DaemonSets{BaseResource: model.BaseResource{Name: ds.Name}}
	}

	return daemonSets, nil
}

func (kcs *K8sClientSet) GetAlertRules() (map[string]map[string]model.Rule, error) {
	alertRulesConfigMap, err := kcs.kubeClient.CoreV1().ConfigMaps(kcs.namespace).Get(kcs.ctx, constant.AlertRulesConfigMap, v1.GetOptions{})

	if err != nil {
		return nil, err
	}

	alertRules := make(map[string]map[string]model.Rule)
	var alerts model.Alerts
	err = yaml.Unmarshal([]byte(alertRulesConfigMap.Data[constant.AlertRulesConfigMapDataKey]), &alerts)

	if err != nil {
		return nil, err
	}

	for _, gr := range alerts.Groups {
		for _, rl := range gr.Rules {
			serviceName := rl.Labels["serviceName"]
			if alertServiceRules, ok := alertRules[serviceName]; ok {
				replaceServiceName(rl, serviceName)
				alertRules[serviceName][rl.AlertName] = rl
			} else {
				alertServiceRules = make(map[string]model.Rule)
				replaceServiceName(rl, serviceName)
				alertServiceRules[rl.AlertName] = rl
				alertRules[serviceName] = alertServiceRules
			}
		}
	}

	return alertRules, nil
}

func replaceServiceName(rule model.Rule, serviceName string) {
	m1 := regexp.MustCompile(`{{ .* }}`)
	rule.Annotations["description"] = m1.ReplaceAllString(rule.Annotations["description"], serviceName)
	rule.Annotations["summary"] = m1.ReplaceAllString(rule.Annotations["summary"], serviceName)
}

func (kcs *K8sClientSet) GetFaultMapping() (ar *v12.ConfigMap, err error) {
	return kcs.kubeClient.CoreV1().ConfigMaps(kcs.namespace).Get(kcs.ctx, constant.FaultMappingsConfigMap, v1.GetOptions{})
}

func getKubeClient(configFilePath string) (*kubernetes.Clientset, error) {
	config, err := os.ReadFile(configFilePath)

	if err != nil {
		return nil, err
	}

	restConfig, err := clientcmd.RESTConfigFromKubeConfig(config)

	if err != nil {
		return nil, err
	}

	kc := kubernetes.NewForConfigOrDie(restConfig)
	return kc, nil
}

func isDataBase(serviceName string) bool {
	return strings.Contains(serviceName, "pg") || strings.Contains(serviceName, "postgres") || strings.Contains(serviceName, "db")
}
