package util

import (
	"cvnfmctl/constant"
	"cvnfmctl/model"
	_ "embed"
	"encoding/csv"
	"encoding/json"
	sprig "github.com/go-task/slim-sprig"
	v12 "k8s.io/api/core/v1"
	"os"
	"slices"
	"strings"
	"text/template"
)

var (
	baseRules = map[string]string{
		constant.Unavailable: constant.ServiceUnavailable,
		constant.Degraded:    constant.ServiceDegraded,
	}

	extendedRules = map[string]string{
		constant.Pending: constant.PvcPendingRule,
		constant.Lost:    constant.PvcLostRule,
	}
)

var exclusion = []string{"eric-eo-vnfm-helm-executor", "eric-eo-cvnfm", "eric-cloud-native-kvdb-rd-operand"}

func FillFaultMapping(alertRules map[string]map[string]model.Rule, faultMappingsConfigMap *v12.ConfigMap) error {
	for fileName, mappings := range faultMappingsConfigMap.Data {
		serviceName := strings.TrimSuffix(fileName, ".json")
		var fms []model.FaultMapping

		err := json.Unmarshal([]byte(mappings), &fms)

		if err != nil {
			return err
		}

		for _, fm := range fms {
			if serviceAlertRules, isServiceAlertRules := alertRules[serviceName]; isServiceAlertRules {
				if alertRule, isAlertRule := serviceAlertRules[fm.FaultName]; isAlertRule {
					alertRule.FaultMapping = fm
					serviceAlertRules[fm.FaultName] = alertRule
				}

				alertRules[serviceName] = serviceAlertRules
			}
		}
	}

	return nil
}

func getMissingResource[T model.ResourcesConstraint](alertRules map[string]map[string]model.Rule, kubeResources map[string]T) []model.MissingAlert {
	missingResource := make([]model.MissingAlert, 0)

	for _, rs := range kubeResources {
		serviceMissingRules := getServiceMissingRules(alertRules[rs.GetName()], rs.HasPVC(), rs.IsDB())

		if len(serviceMissingRules) != 0 {
			missingResource = append(missingResource, model.MissingAlert{
				ServiceName:       rs.GetName(),
				MissingAlertRules: serviceMissingRules,
			})
		}
	}

	return missingResource
}

func GetMissingAlertRules(kubeResources *model.Resources, alertRules map[string]map[string]model.Rule) (map[string][]model.MissingAlert, error) {
	missingAlertRules := make(map[string][]model.MissingAlert)

	missingAlertRules[constant.Deployment] = getMissingResource(alertRules, kubeResources.Deployments)
	missingAlertRules[constant.StatefulSets] = getMissingResource(alertRules, kubeResources.StatefulSets)
	missingAlertRules[constant.DaemonSets] = getMissingResource(alertRules, kubeResources.DaemonSets)

	return missingAlertRules, nil
}

func GetRedundantAlertRules(kubeResources *model.Resources, alertRules map[string]map[string]model.Rule) ([]string, error) {
	redundantAlertRules := make([]string, 0)

	for serviceAlertKey := range alertRules {
		isRedundant := true

		if _, ok := kubeResources.Deployments[serviceAlertKey]; ok {
			isRedundant = false
		}

		if _, ok := kubeResources.StatefulSets[serviceAlertKey]; ok {
			isRedundant = false
		}

		if _, ok := kubeResources.DaemonSets[serviceAlertKey]; ok {
			isRedundant = false
		}

		if slices.Contains(exclusion, serviceAlertKey) {
			isRedundant = false
		}

		if isRedundant {
			redundantAlertRules = append(redundantAlertRules, serviceAlertKey)
		}
	}

	return redundantAlertRules, nil
}

func getServiceMissingRules(serviceRules map[string]model.Rule, pvc, db bool) []string {
	serviceMissingRules := make([]string, 0)

	for pattern, rule := range baseRules {
		if !containsRule(pattern, serviceRules) {
			serviceMissingRules = append(serviceMissingRules, rule)
		}
	}

	if pvc {
		for pattern, rule := range extendedRules {
			if !containsRule(pattern, serviceRules) {
				serviceMissingRules = append(serviceMissingRules, rule)
			}
		}

		if db && !containsRule(constant.LowDiskSpace, serviceRules) {
			serviceMissingRules = append(serviceMissingRules, constant.PvcLowDiskSpaceRule)
		}
	}

	return serviceMissingRules
}

func containsRule(pattern string, rules map[string]model.Rule) bool {
	for _, rule := range rules {
		if strings.Contains(rule.AlertName, pattern) {
			return true
		}
	}

	return false
}

func GetMissingFaultMappings(alertRules map[string]map[string]model.Rule) (map[string][]string, error) {
	missingFaultMappings := make(map[string][]string)

	for alertServiceKey, alertServiceRules := range alertRules {
		missingServiceFaultMappings := make([]string, 0)

		for _, rule := range alertServiceRules {
			if len(rule.FaultMapping.FaultName) == 0 {
				missingServiceFaultMappings = append(missingServiceFaultMappings, rule.AlertName)
			}
		}

		if len(missingServiceFaultMappings) != 0 {
			missingFaultMappings[alertServiceKey] = missingServiceFaultMappings
		}
	}

	return missingFaultMappings, nil
}

func GenerateTemplate(reportData interface{}, reportTemplate, reportName, reportFileName string) error {
	tmpl, err := template.New(reportName).Funcs(sprig.FuncMap()).Parse(reportTemplate)

	if err != nil {
		return err
	}

	rep, err := os.Create(reportFileName)

	if err != nil {
		return err
	}

	defer rep.Close()
	return tmpl.Execute(rep, reportData)
}

func GenerateCSV(reportName string, csvRows [][]string) error {
	outputFile, err := os.Create(reportName)

	if err != nil {
		return err
	}

	defer outputFile.Close()

	writer := csv.NewWriter(outputFile)
	defer writer.Flush()

	return writer.WriteAll(csvRows)
}

func GetActualRules(alertRules map[string]map[string]model.Rule, kubeResources *model.Resources) map[string]map[string]model.Rule {
	actualAlertRules := make(map[string]map[string]model.Rule)

	for serviceName, rules := range alertRules {
		if _, ok := kubeResources.Deployments[serviceName]; ok {
			actualAlertRules[serviceName] = rules
			continue
		}

		if _, ok := kubeResources.StatefulSets[serviceName]; ok {
			actualAlertRules[serviceName] = rules
			continue
		}

		if _, ok := kubeResources.DaemonSets[serviceName]; ok {
			actualAlertRules[serviceName] = rules
			continue
		}

		if slices.Contains(exclusion, serviceName) {
			actualAlertRules[serviceName] = rules
			continue
		}
	}

	return actualAlertRules
}
