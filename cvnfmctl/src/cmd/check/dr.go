package check

import (
	"cvnfmctl/global_var"
	"cvnfmctl/report"
	"github.com/spf13/cobra"
)

var dr = &cobra.Command{
	Use:   "dr",
	Short: "Generate report about HA Design Rules",
	Run: func(cmd *cobra.Command, args []string) {
		err := report.GenerateDRReport(global_var.Kubeconfig, global_var.Namespace)

		if err != nil {
			cmd.PrintErrln("Error:", err)
			cmd.Help()
			cmd.PrintErrln("")
			cmd.PrintErrln(err)
		}
	},
}

func init() {
	dr.PersistentFlags().StringVarP(&global_var.Kubeconfig, "kubeconfig", "k", "", "path to your kubeconfig. If not specified, the file in the home/.kube/config directory will be taken ")

	dr.PersistentFlags().StringVarP(&global_var.Namespace, "namespace", "n", "", "your namespace where evnfm is deployed (*required)")
	dr.MarkPersistentFlagRequired("namespace")
}
