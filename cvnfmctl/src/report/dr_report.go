package report

import (
	"context"
	"cvnfmctl/constant"
	"cvnfmctl/helm"
	"cvnfmctl/kubernetes"
	"cvnfmctl/model"
	"cvnfmctl/util"
	_ "embed"
	"errors"
	"fmt"
	"k8s.io/client-go/util/homedir"
	"path/filepath"
	"time"
)

//go:embed dr-report-template.txt
var reportTemplate string

func GenerateDRReport(configFilePath, namespace string) error {
	var err error

	if configFilePath == "" {
		if home := homedir.HomeDir(); home != "" {
			configFilePath = filepath.Join(homedir.HomeDir(), ".kube", "config")
		} else {
			err = errors.New("couldn't find kubeconfig, specify the path to kubeconfig directly via the flag")
			return err
		}
	}

	k8s, err := kubernetes.NewK8sClientSet(context.Background(), configFilePath, namespace)

	if err != nil {
		return err
	}

	reportData := &model.DRReport{}
	reportData.Releases, err = helm.GetReleases(configFilePath, namespace)

	if err != nil {
		return err
	}

	reportData.KubeControllers, err = k8s.GetKubeControllers()

	if err != nil {
		return err
	}

	//TODO
	//Multiple instances(pods)  (DR-D1120-046)                   | ???????????????????????????????                                           |
	//anti-affinity rules (DR-D1120-050)                         | Deprecated DR                                                             |
	//resource profile (request and limits) (DR-D1126-005)       | kc.CoreV1().Pods(namespace).List(ctx, v1.ListOptions{})                   | Spec.Containers[0].Resources.Limits["cpu"]
	//Health probe (DR-D1120-011)                                | ??????????????????????????                                                |
	//PDB (DR-D1120-056)                                         | kc.AppsV1().Deployments(namespace).List(ctx, v1.ListOptions{})            | ObjectMeta.Spec.Strategy.RollingUpdate
	//rolling update, maxSurge and maxUnavailable (DR-D1120-030) | kc.PolicyV1().PodDisruptionBudgets(namespace).List(ctx, v1.ListOptions{}) | ObjectMeta.Spec.MinAvailable

	//TODO
	//rolling update, maxSurge and maxUnavailable (DR-D1120-030)
	reportData.Strategy, err = k8s.GetStrategy(namespace)

	//TODO
	//add check to filter out the necessary cases for reportData.RollingUpdates

	if err != nil {
		return err
	}

	currentTime := time.Now().Format(constant.TimeLayout)

	reportName := fmt.Sprintf("%s-%s-%s.%s", constant.DRReportName, namespace, currentTime, constant.TXTExtension)

	return util.GenerateTemplate(reportData, reportTemplate, constant.AlertReportName, reportName)
}
