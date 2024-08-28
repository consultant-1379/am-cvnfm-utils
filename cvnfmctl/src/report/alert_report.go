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

//go:embed alert-report-template.txt
var alertReportTemplate string

func GenerateAlertReport(configFilePath, namespace string) error {
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

	alertReportData := &model.AlertReport{}
	alertReportData.Releases, err = helm.GetReleases(configFilePath, namespace)

	if err != nil {
		return err
	}

	alertReportData.KubeControllers, err = k8s.GetKubeControllers()

	if err != nil {
		return err
	}

	alertRules, err := k8s.GetAlertRules()

	if err != nil {
		return err
	}

	alertReportData.MissingAlerts, err = util.GetMissingAlertRules(alertReportData.KubeControllers, alertRules)

	if err != nil {
		return err
	}

	alertReportData.RedundantAlertRules, err = util.GetRedundantAlertRules(alertReportData.KubeControllers, alertRules)

	if err != nil {
		return err
	}

	faultMappingsConfigMap, err := k8s.GetFaultMapping()

	if err != nil {
		return err
	}

	err = util.FillFaultMapping(alertRules, faultMappingsConfigMap)

	if err != nil {
		return err
	}

	alertReportData.MissingFaultMappings, err = util.GetMissingFaultMappings(alertRules)

	if err != nil {
		return err
	}

	currentTime := time.Now().Format(constant.TimeLayout)

	reportName := fmt.Sprintf("%s-%s-%s.%s", constant.AlertReportName, namespace, currentTime, constant.TXTExtension)

	return util.GenerateTemplate(alertReportData, alertReportTemplate, constant.AlertReportName, reportName)
}
