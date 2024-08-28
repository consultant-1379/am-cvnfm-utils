package constant

const (
	AlertRulesConfigMap        = "eric-cnbase-oss-config-oss-alerting-rules"
	AlertRulesConfigMapDataKey = "eric-cnbase-oss-config-oss-alerting-rules.yml"
	FaultMappingsConfigMap     = "eric-cnbase-oss-config-oss-faultmappings"
)

const (
	Unavailable         = "Unavailable"
	Degraded            = "Degraded"
	Pending             = "PVCPending"
	Lost                = "PVCLost"
	LowDiskSpace        = "PVCLowDiskSpace"
	ServiceUnavailable  = "Service unavailable"
	ServiceDegraded     = "Service degraded"
	PvcPendingRule      = "PVC pending"
	PvcLostRule         = "PVC lost"
	PvcLowDiskSpaceRule = "PVC Low Disk Space"
)

const (
	Deployment   = "Deployment"
	StatefulSets = "StatefulSets"
	DaemonSets   = "DaemonSets"
)

const (
	AlertReportName     = "alert-report"
	AlertListReportName = "alert-list-report"
	DRReportName        = "dr-report"
	TXTExtension        = "txt"
	CSVExtension        = "csv"
)

const (
	TimeLayout = "Jan-2-2006_15:04:05"
)
