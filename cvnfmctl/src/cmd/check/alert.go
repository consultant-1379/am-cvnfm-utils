package check

import (
	"cvnfmctl/global_var"
	"cvnfmctl/report"
	"github.com/spf13/cobra"
)

var alert = &cobra.Command{
	Use:   "alert",
	Short: "Generate missing alert rules and fault mappings report",
	Run: func(cmd *cobra.Command, args []string) {
		err := report.GenerateAlertReport(global_var.Kubeconfig, global_var.Namespace)

		if err != nil {
			cmd.PrintErrln("Error:", err)
			cmd.Help()
			cmd.PrintErrln("")
			cmd.PrintErrln(err)
		}
	},
}

func init() {
	alert.PersistentFlags().StringVarP(&global_var.Kubeconfig, "kubeconfig", "k", "", "path to your kubeconfig. If not specified, the file in the home/.kube/config directory will be taken ")

	alert.PersistentFlags().StringVarP(&global_var.Namespace, "namespace", "n", "", "your namespace where evnfm is deployed (*required)")
	alert.MarkPersistentFlagRequired("namespace")
}
