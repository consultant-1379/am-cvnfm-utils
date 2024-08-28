package check

import (
	"github.com/spf13/cobra"
)

var Check = &cobra.Command{
	Use:   "check",
	Short: "Check one of many information about cvnfm",
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

func init() {
	Check.AddCommand(alert)
	Check.AddCommand(dr)
}
