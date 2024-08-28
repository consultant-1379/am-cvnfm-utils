package report

import (
	"context"
	"cvnfmctl/constant"
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

//go:embed alert-list-report-template.txt
var alertListReportTemplate string

func GenerateAlertListReport(configFilePath, namespace, format string, allRules bool) (error, map[string]map[string]model.Rule) {
	var err error

	if configFilePath == "" {
		if home := homedir.HomeDir(); home != "" {
			configFilePath = filepath.Join(homedir.HomeDir(), ".kube", "config")
		} else {
			err = errors.New("couldn't find kubeconfig, specify the path to kubeconfig directly via the flag")
			return err, nil
		}
	}

	k8s, err := kubernetes.NewK8sClientSet(context.Background(), configFilePath, namespace)

	if err != nil {
		return err, nil
	}

	kubeControllers, err := k8s.GetKubeControllers()

	if err != nil {
		return err, nil
	}

	alertRules, err := k8s.GetAlertRules()

	if err != nil {
		return err, nil
	}

	faultMappingsConfigMap, err := k8s.GetFaultMapping()

	if err != nil {
		return err, nil
	}

	err = util.FillFaultMapping(alertRules, faultMappingsConfigMap)

	if err != nil {
		return err, nil
	}

	if !allRules {
		alertRules = util.GetActualRules(alertRules, kubeControllers)
	}

	currentTime := time.Now().Format(constant.TimeLayout)

	switch format {
	case "txt":
		reportName := fmt.Sprintf("%s-%s-%s.%s", constant.AlertListReportName, namespace, currentTime, constant.TXTExtension)
		return util.GenerateTemplate(alertRules, alertListReportTemplate, constant.AlertListReportName, reportName), alertRules
	case "csv":
		reportName := fmt.Sprintf("%s-%s-%s.%s", constant.AlertListReportName, namespace, currentTime, constant.CSVExtension)

		header := []string{"service name", "alert name", "severity", "faulty resource", "summary", "description", "code"}
		var csvRows [][]string
		csvRows = append(csvRows, header)

		for _, rules := range alertRules {
			for _, rule := range rules {
				var csvRow []string
				csvRow = append(csvRow, rule.Labels["serviceName"], rule.AlertName, rule.Labels["severity"], rule.Labels["faultyResource"], rule.Annotations["summary"], rule.FaultMapping.DefaultDescription, fmt.Sprint(rule.FaultMapping.Code))
				csvRows = append(csvRows, csvRow)
			}
		}

		return util.GenerateCSV(reportName, csvRows), alertRules
	default:
		err = errors.New(fmt.Sprintf("unknown format: %s", format))
	}

	return err, nil
}
