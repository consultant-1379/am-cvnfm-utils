package get

import (
	"github.com/spf13/cobra"
)

var Get = &cobra.Command{
	Use:   "get",
	Short: "Get one of many information about cvnfm",
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

func init() {
	Get.AddCommand(alertList)
}
