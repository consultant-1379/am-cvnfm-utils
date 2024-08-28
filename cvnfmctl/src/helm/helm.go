package helm

import (
	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/cli"
	"log"
	"os"
)

func GetReleases(configFilePath, namespace string) (map[string]string, error) {
	helmSettings := getHelmSettings(configFilePath, namespace)
	listAction, err := configureListAction(helmSettings)

	if err != nil {
		return nil, err
	}

	rls, err := listAction.Run()

	if err != nil {
		return nil, err
	}

	res := make(map[string]string)

	for _, rl := range rls {
		res[rl.Name] = rl.Chart.Metadata.Version
	}

	return res, nil
}

func getHelmSettings(configFilePath, namespace string) *cli.EnvSettings {
	helmSettings := cli.New()
	helmSettings.KubeConfig = configFilePath
	helmSettings.SetNamespace(namespace)

	return helmSettings
}

func getActionConfig(helmSettings *cli.EnvSettings) (*action.Configuration, error) {
	actionConfig := new(action.Configuration)

	if err := actionConfig.Init(helmSettings.RESTClientGetter(), helmSettings.Namespace(), os.Getenv("HELM_DRIVER"), log.Printf); err != nil {
		return nil, err
	}

	return actionConfig, nil
}

func configureListAction(helmSettings *cli.EnvSettings) (*action.List, error) {
	actionConfig, err := getActionConfig(helmSettings)

	if err != nil {
		return nil, err
	}

	return action.NewList(actionConfig), nil
}
