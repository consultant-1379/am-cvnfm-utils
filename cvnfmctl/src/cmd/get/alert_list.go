package get

import (
	"cvnfmctl/global_var"
	"cvnfmctl/report"
	"github.com/spf13/cobra"
)

var format string
var allRules bool
var print bool

var alertList = &cobra.Command{
	Use:   "alertlist",
	Short: "Generates report with a description of all alarms",
	Run: func(cmd *cobra.Command, args []string) {
		err, alertRules := report.GenerateAlertListReport(global_var.Kubeconfig, global_var.Namespace, format, allRules)

		if err != nil {
			cmd.PrintErrln("Error:", err)
			cmd.Help()
			cmd.PrintErrln("")
			cmd.PrintErrln(err)
		}

		if print {
			for _, rules := range alertRules {
				for _, rule := range rules {
					cmd.Println(rule.AlertName)
				}
			}
		}
	},
}

func init() {
	alertList.PersistentFlags().StringVarP(&global_var.Kubeconfig, "kubeconfig", "k", "", "path to your kubeconfig. If not specified, the file in the home/.kube/config directory will be taken ")

	alertList.PersistentFlags().StringVarP(&global_var.Namespace, "namespace", "n", "", "your namespace where evnfm is deployed (*required)")
	alertList.MarkPersistentFlagRequired("namespace")

	alertList.PersistentFlags().StringVarP(&format, "format", "f", "csv", "output format. Supported formats csv, txt")
	alertList.PersistentFlags().BoolVarP(&allRules, "allRules", "a", false, "output all rules. By default, only rules for which services are deployed are output")
	alertList.PersistentFlags().BoolVarP(&print, "print", "p", false, "print in console alert names")
}
