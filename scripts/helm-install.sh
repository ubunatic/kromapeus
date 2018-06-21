#!/usr/bin/env bash
set -o errexit

GRAF="
image:
  tag: 5.0.4
persistence:
  enabled: true
  size: 1Gi
  accessModes:
  - ReadWriteOnce
# existingClaim: graf-grafana
"
here=`dirname $0`
bin=`readlink -f $here/../bin`
PATH=$PATH:$bin

first_pod(){ kubectl get pods -l "$@" -o jsonpath='{.items[0].metadata.name}'; }
upgrade()  { helm upgrade --install "$@"; }
log()      { echo "$@" 1>&2; }

install_helm(){
	$here/helm-user-install.sh
	$here/allow-admin.sh yes

	helm init --upgrade
	log -n "Waiting for tiller"
	while true; do
		helm list 2> /dev/null && break || log -n "."; sleep 1
	done 
}

forward_ports(){
	trap 'kill %1 %2 %3' TERM INT
	kubectl port-forward `first_pod "app=grafana"`                           3000:3000 &
	kubectl port-forward `first_pod "app=prometheus,component=server"`       9090:9090 &
	kubectl port-forward `first_pod "app=prometheus,component=alertmanager"` 9093:9093 &

	log "waiting for proxies:
	graf-grafana:            http://localhost:3000
	prometheus-server:       http://localhost:9090
	prometheus-alertmanager: http://localhost:9393
	"
	wait
}

prom(){ upgrade prom stable/prometheus --force --wait; }
graf(){ upgrade graf stable/grafana -f <(echo "$GRAF") --wait --debug; }

secret(){ kubectl get secret graf-grafana -o jsonpath='{.data.admin-password}' | base64 --decode; echo; }

while test $# -gt 0; do case $1 in
	ins*|helm) install_helm;;
	up*|dep*)  prom; graf;;
	prom*)     prom;;
	graf*)     graf;;
	sec*)      secret;;
	fwd|forw*|proxy) forward_ports;;
	*)               log "invalid command $action"; exit 1;;
esac; shift; done
