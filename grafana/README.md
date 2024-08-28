## Install Prometheus via script

Prometheus (with grafana/alertmanager/reporter/renderer) can be installed via using script ./script/**grafana-deploy.sh**.
By default, script deploys all stuff to **evnfm-metrics** namespace, but can be changed to any namespace or in script itself either by 
passing parameter:
```
    sh grafana-deploy.sh --n <ns>
```
Deleting prometheus and all related services, installed with script, can be done via running:
```
    sh grafana-deploy.sh --d --n <ns>
```
**Note**: *Try to forward prometheus namespace naming convention that is stands for* **evnfm-metrics** *name*

### Adding dashboards to grafana
Import next Grafana dashboards from ./dashboard:
   * To be used with default Prometheus data source:  
     * CVNFM-Containers Metrics.json - different metrics per each container for CVNFM services
     * ADP-Container Metrics.json - different metrics per each container for ADP services
     * EO-Common-Container Metrics.json - different metrics per each container for EO common services (using mainly on co-deploy)

   * To be used with EO prometheus data source (eric-pm-server from the deployment):
     * EVNFM-RED Metrics All.json - networking and REST related metrics per instance (application, service)
     * EVNFM-USE Metrics.json - JVM related metrics per instance (application, service)

### Configuring eric-pm-server data source

Firstly, prometheus-ingress.yaml contains host for eric-pm-server, that should be changed to desired value, e.g.\
from:
```
    - host: prometheus.<signum>.<cluster>.ews.gic.ericsson.se
```
to
```
    - host: prometheus.zyurpin.hart070-iccr.ews.gic.ericsson.se
```

**Note:** Be aware applying ingress for *iccr* or *nginx* - assign to correct controller. For customer-like environments only *nginx* is 
applicable.

Secondly, from the directory ./files apply next 2 files:
```
    kubectl apply -f prometheus-ingress.yaml -n <ns>
    kubectl apply -f prometheus-network-policy.yaml -n <ns>
```

Thirdly, navigate to grafana UI data sources section and create new prometheus data source. In created data source, pass to the URL value from the
prometheus-ingress.yaml in form:
```
    http://prometheus.zyurpin.hart070-iccr.ews.gic.ericsson.se/metrics/viewer
```
Mark **Skip TLS verify**, then **Save & test**.\
Now dashboards should display metrics for the chosen eric-pm-server data source.
     
## Install kube-prometheus-stack

This is an alternative way of installing prometheus, but sometimes can be used.
From the ./chart directory run:
```
helm install prometheus kube-prometheus-stack.tgz \
--set alertmanager.enabled=true \
--set grafana.image.repository=armdockerhub.rnd.ericsson.se/grafana/grafana \
--set grafana.image.tag=8.5.1 \
--set grafana.imageRenderer.enabled=true \
--set grafana.imageRenderer.image.repository=armdockerhub.rnd.ericsson.se/grafana/grafana-image-renderer \
--set grafana.imageRenderer.tag=3.4.2 \
--set grafana.imageRenderer.networkPolicy.limitIngress=false \
--set grafana.ingress.enabled=true \
--set grafana.ingress.hosts={grafana.<CLUSTER>.<ERICSSON_SUFFIX>} \
--set grafana.reporter.enabled=true \
--set grafana.reporter.ingress.host=reporter.<CLUSTER>.<ERICSSON_SUFFIX> \
-n evnfm-metrics --wait
```

For removing kube-prometheus-stack run:
```helm uninstall prometheus -n evnfm-metrics```