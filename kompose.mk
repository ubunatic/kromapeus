.PHONY: kompose charts-clean chart-vars

# Kompose setup
# =============
export PATH := $(PATH):$(CURDIR)/bin

kompose:          ; which kompose || go get -u github.com/kubernetes/kompose
chart: chart-vars ; $(VARS) kompose convert -c -o chart
clean: charts-clean

CHARTNAMES = $(SERVICES)
CHARTS     = $(addprefix charts/,$(CHARTNAMES))
charts: chart $(CHARTS)
$(CHARTS): charts/%:
	# base:  $@
	# match: $*
	mkdir -p $@/templates
	cp chart/Chart.yaml $@
	cp chart/templates/$*-*.yaml $@/templates

charts-clean: ; rm -rf chart charts

vars: chart-vars
chart-vars:
	# CHARTNAMES: $(CHARTNAMES)
	# CHARTS:     $(CHARTS)
	# APPS:       $(APPS)
	# SERVICES:   $(SERVICES)

# Templating
# ==========
.PHONY: j2-prom

PROM_YML = images/prometheus/prometheus.yml
j2-prom: $(PROM_YML)

PROM_TARGETS    = $(patsubst %,"%:8080",$(APPS))
PROM_TARGETS_J2 = $(shell echo '$(PROM_TARGETS)' | sed 's/ /, /g')
$(PROM_YML):
	scripts/jinja -f $@.j2 TARGETS='$(PROM_TARGETS_J2)' > $@
	grep targets -A 1 -B 1 $@

# Basic Cluster Management using gcloud command
# =============================================
.PHONY: cluster-creds cluster-scale cluster-vars

# The default cluster is the configured cluster on the current shell.
# Please use CLUSTER=PROJECT/ZONE/NAME to override.
CLUSTER  = $(shell scripts/gke ls --first)
PROJECT  = $(shell gcloud config get-value project)
REGISTRY = gcr.io
POOL     = $(shell scripts/gke ls --resource node-pools --cluster $(CLUSTER) --first)
SIZE     = 3

# get access to the cluster using current google credentials
cluster-creds:	
	scripts/gke creds --cluster $(CLUSTER)
	kubectl get pods  # test if we can talk to the cluster

ALLOW_ADMIN=false
cluster-allow-admin: ; scripts/install-helm admin $(ALLOW_ADMIN)

# resize the cluster, set SIZE=<number> to change the size
cluster-scale:
	scripts/gke scale --pool $(POOL) --size $(SIZE)

cluster-vars:
	# REGISTRY: $(REGISTRY)
	# CLUSTER:  $(CLUSTER)
	# POOL:     $(POOL)
	# IMAGES:   $(IMAGES)
	# SIZE:     $(SIZE)


# Advanced Cluster Management using Helm
# ======================================
.PHONY: helm cluster-allow-admin docker-auth push $(PUSH_TARGETS)
IMAGES    = $(patsubst %,$(REGISTRY)/$(PROJECT)/%,$(APP) grafana prometheus)
APP_IMAGE = $(patsubst %,$(REGISTRY)/$(PROJECT)/%,$(APP))

helm: bin/helm
bin/helm: ; scripts/install-helm install $(CURDIR)/bin
docker-auth: ; gcloud auth configure-docker

# targets for manually pusing images (kompose -c --build local will do this automatically)
PUSH_TARGETS = $(patsubst %,push-%,$(IMAGES))
push-all: $(PUSH_TARGETS)
$(PUSH_TARGETS): push-%: docker-auth ; docker push $*
push: push-$(APP_IMAGE)

# upgrade images, chart, and deployment
RECREATE_ARGS =
HELM_ARGS  =
HELM       = bin/helm
NAMESPACE  = default
CHART      = $(APP)

.PHONY: helm-delete helm-recreate helm-upgrade helm-clean helm-purge helm-init upgrade
helm-delete: ; $(HELM) delete $(CHART) --purge $(HELM_ARGS) || true
helm-upgrade: ; $(HELM) upgrade $(CHART) charts/$(CHART) -i --wait --namespace $(NAMESPACE) $(HELM_ARGS) $(RECREATE_ARGS)
helm-recreate: RECREATE_ARGS = --recreate-pods --reset-values
helm-recreate: helm-upgrade

helm-clean: helm-delete ; rm -rf bin/helm scripts/get_helm.sh chart
helm-purge: helm-clean  ; kubectl delete deployment tiller-deploy --purge 2> /dev/null || true
helm-init: helm cluster-allow-admin;
	$(HELM) init --upgrade
	while ! $(HELM) list; do sleep 10; done  # wait for tiller pod

helm-all: ; for c in $(CHARTNAMES); do $(MAKE) helm-$(HELM_TASK) CHART=$$c; done
upgrade-all: HELM_TASK=upgrade
upgrade-all: helm-all
recreate-all: HELM_TASK=upgrade
recreate-all: helm-all

upgrade: build push charts helm upgrade-all

# Cluster Creation, Deletion, and Forwarding
# ==========================================
.PHONY: cluster-forward cluster-forwards cluster-1-up cluster-2-down cluster-ensure cluster-fix cluster

POD = $(shell kubectl get pod --selector="io.kompose.service=$(SERVICE)" -o jsonpath='{.items[0].metadata.name}')
SERVICE = grafana
PORTS = 3001:3000
cluster-forward:
	@echo creating '$(SERVICE)' service forward from http://0.0.0.0:$(subst :, to ,$(PORTS)) > /dev/stderr
	kubectl port-forward $(POD) $(PORTS)

cluster-forwards:
	# create and detach all three port-forwards and wait for the jobs to exit
	bash -i -o errexit -c ' \
	trap "jobs -p | xargs kill" INT TERM EXIT; \
	$(MAKE) cluster-forward SERVICE=prometheus  PORTS=9091:9090 & \
	$(MAKE) cluster-forward SERVICE=grafana     PORTS=3001:3000 & \
	$(MAKE) cluster-forward SERVICE=$(APP)      PORTS=8081:8080 & \
	wait'

ZONE=us-central1-a  # used only for cluster creation/deletion
cluster-1-up:
	# create new lean cluster that has less admin pods, thanks to
	# the disabled features
	gcloud container clusters create cluster-1 \
		--num-nodes=$(SIZE) --project $(PROJECT) --zone=$(ZONE) \
		--cluster-version 1.9.7-gke.0 \
		--node-version 1.9.7-gke.0 \
		--machine-type f1-micro \
		--no-enable-autorepair \
		--no-enable-autoscaling \
		--no-enable-autoupgrade \
		--no-enable-cloud-monitoring \
		--no-enable-cloud-logging \
		--addons NetworkPolicy

cluster-1-down:
	gcloud container clusters delete cluster-1 --project $(PROJECT) --zone=$(ZONE) || true

cluster-ensure:
	# ensure we have at least one clusterto play with
	test -n $(CLUSTER) || $(MAKE) cluster-1-up

cluster-fix: ; scripts/fix-limits.sh

# all-in-one-target to bootstrap Kromapeus in the Google Cloud
cluster:	cluster-ensure cluster-creds cluster-allow-admin cluster-fix helm helm-init chart helm-upgrade
