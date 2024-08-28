package model

type EricProductInfo struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
}

type AlertReport struct {
	Releases             map[string]string
	KubeControllers      *Resources
	MissingAlerts        map[string][]MissingAlert
	MissingFaultMappings map[string][]string
	RedundantAlertRules  []string
}

type DRReport struct {
	Releases        map[string]string
	KubeControllers *Resources
	Strategy        map[string]interface{}
}

type MissingAlert struct {
	ServiceName       string
	MissingAlertRules []string
}

type FaultMapping struct {
	FaultName          string `json:"faultName"`
	Code               int64  `json:"code"`
	DefaultDescription string `json:"defaultDescription"`
}

type Rule struct {
	AlertName    string            `yaml:"alert"`
	Labels       map[string]string `yaml:"labels"`
	Annotations  map[string]string `yaml:"annotations"`
	FaultMapping FaultMapping
}

type Group struct {
	Rules []Rule `yaml:"rules"`
}

type Alerts struct {
	Groups []Group `yaml:"groups"`
}

type BaseResource struct {
	Name string
}

type Deployment struct {
	BaseResource
}

type DaemonSets struct {
	BaseResource
}

type StatefulSet struct {
	BaseResource
	PVC bool
	DB  bool
}

type Resources struct {
	Deployments  map[string]Deployment
	StatefulSets map[string]StatefulSet
	DaemonSets   map[string]DaemonSets
}

type ResourcesConstraint interface {
	GetName() string
	HasPVC() bool
	IsDB() bool
}

func (baseResource BaseResource) GetName() string {
	return baseResource.Name
}

func (baseResource BaseResource) HasPVC() bool {
	return false
}

func (baseResource BaseResource) IsDB() bool {
	return false
}

func (statefulSets StatefulSet) HasPVC() bool {
	return statefulSets.PVC
}

func (statefulSets StatefulSet) IsDB() bool {
	return statefulSets.DB
}
