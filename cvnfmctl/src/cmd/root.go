package cmd

import (
	"cvnfmctl/cmd/check"
	"cvnfmctl/cmd/get"
	"fmt"
	"github.com/spf13/cobra"
	"os"
)

var root = &cobra.Command{
	Short: "cvnfmctl is a CLI tool for checking and verifying information about cvnfm",
	Use:   "cvnfmctl",
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

func init() {
	root.CompletionOptions.DisableDefaultCmd = true
	root.AddCommand(get.Get)
}

func Execute(isCustomerBuild bool, ericProductInfo string) {
	root.Version = ericProductInfo

	if !isCustomerBuild {
		root.AddCommand(check.Check)
	}

	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
