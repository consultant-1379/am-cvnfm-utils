package main

import (
	"cvnfmctl/cmd"
	"cvnfmctl/model"
	_ "embed"
	"fmt"
	"gopkg.in/yaml.v3"
	"os"
)

//go:embed eric-product-info.yaml
var ericProductInfo string
var isCustomerBuild = false

func main() {
	var ericProductInfoYaml model.EricProductInfo
	err := yaml.Unmarshal([]byte(ericProductInfo), &ericProductInfoYaml)

	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	cmd.Execute(isCustomerBuild, ericProductInfoYaml.Version)
}
