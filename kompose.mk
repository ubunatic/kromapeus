.PHONY: all kompose example example-run

export PATH := $(PATH):$(CURDIR)/bin

MINIKUBE_URL = https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

all: bin/minikube kompose

bin/minikube:
	mkdir -p bin
	curl -Lo bin/minikube $(MINIKUBE_URL)
	chmod +x bin/minikube
	# TODO (uj): let minikube run in docker to avoid sudo

EXAMPLE     = data/examples/docker-compose.yaml
EXAMPLE_DIR = $(shell dirname $(EXAMPLE))
example-run:     kompose $(EXAMPLE); cd $(EXAMPLE_DIR) && kompose up
example: $(EXAMPLE)
$(EXAMPLE):
	mkdir -p $(EXAMPLE_DIR) && cd $(EXAMPLE_DIR) && \
	  wget https://raw.githubusercontent.com/kubernetes/kompose/master/examples/docker-compose.yaml

kompose:
	which kompose || go get -u github.com/kubernetes/kompose

# Basic Cluster Management using gcloud command
# =============================================
.PHONY: cluster-creds cluster-scale cluster-vars

# The default cluster is the configured cluster on the current shell.
# Please use CLUSTER=PROJECT/ZONE/NAME to override.
PROJECT  = $(shell gcloud config get-value project)
CLUSTER = $(shell scripts/cluster ls --first)
POOL     = $(shell scripts/cluster ls --resource node-pools --cluster $(CLUSTER) --first)
SIZE     = 2

# get access to the cluster using current google credentials
cluster-creds:	
	scripts/cluster creds --cluster $(CLUSTER)
	kubectl get pods  # test if we can talk to the cluster

# resize the cluster, set SIZE=<number> to change the size
cluster-scale:
	scripts/cluster scale --pool $(POOL) --size $(SIZE)

cluster-vars:
	# CLUSTER:  $(CLUSTER)
	# POOL:     $(POOL)
	# IMAGES:   $(IMAGES)
	# SIZE:     $(SIZE)

# Advanced Cluster Management using helm
# ======================================
.PHONY: helm docker-auth push
# The default cluster is the configured cluster on the current shell.
# Please use CLUSTER=PROJECT/ZONE/NAME to override.
REGISTRY = gcr.io
IMAGES = $(patsubst %,$(REGISTRY)/$(PROJECT)/%,py-http-server grafana prometheus)

helm: bin/helm
bin/helm: authenticate-helm
	mkdir -p bin
	curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > scripts/get_helm.sh
	chmod +x scripts/get_helm.sh
	EUID=0 HELM_INSTALL_DIR=bin scripts/get_helm.sh

YES=false
authenticate-helm:
	if $(YES); then key=y; else \
		read -p "Allow helm to adminster cluster using default service account? (y|N)" key; \
	fi; \
	if test "$$key" = "y"; then \
		kubectl create clusterrolebinding add-on-cluster-admin \
			--clusterrole=cluster-admin --serviceaccount=kube-system:default; \
	fi || true

# recreate all chart from compose file
chart:
	_REG=$(REGISTRY) _PRJ=$(PROJECT) kompose convert -c -o chart

docker-auth: ; gcloud auth configure-docker

# targets for manually pusing images (kompose -c --build local will do this automatically)
PUSH_TARGETS = $(patsubst %,push-%,$(IMAGES))
push: $(PUSH_TARGETS)
$(PUSH_TARGETS): push-%: docker-auth ; docker push $*

# upgrade images, chart, and deployment
HELM_ARGS =
RECREATE_ARGS =
HELM      = bin/helm
NAMESPACE = default

helm-delete: ; $(HELM) delete kromapeus --purge $(HELM_ARGS) || true
helm-recreate: RECREATE_ARGS = --recreate-pods --reset-values
helm-recreate: helm-upgrade
helm-upgrade: ; $(HELM) upgrade kromapeus chart -i --wait --force \
	--namespace $(NAMESPACE) $(HELM_ARGS) $(RECREATE_ARGS)

helm-clean: helm-delete ; rm -rf bin/helm scripts/get_helm.sh chart
helm-init: authenticate-helm; $(HELM) init --upgrade
helm-purge: helm-delete ; kubectl delete deployment tiller-deploy --purge 2> /dev/null || true

upgrade: build push chart helm helm-upgrade

POD = $(shell kubectl get pod --selector="io.kompose.service=$(SERVICE)" -o jsonpath='{.items[0].metadata.name}')
SERVICE = grafana
PORTS = 3001:3000
cluster-forward:
	@echo creating '$(SERVICE)' service forward from http://0.0.0.0:$(subst :, to ,$(PORTS)) > /dev/stderr
	kubectl port-forward $(POD) $(PORTS)

cluster-forwards:
	bash -i -o errexit -c ' \
	trap "jobs -p | xargs kill" INT TERM EXIT; \
	$(MAKE) cluster-forward SERVICE=prometheus  PORTS=9091:9090 & \
	$(MAKE) cluster-forward SERVICE=grafana     PORTS=3001:3000 & \
	$(MAKE) cluster-forward SERVICE=http-server PORTS=8081:8080 & \
	wait'

ZONE=us-central1-a  # used only for cluster creation
cluster-up:
	gcloud container clusters create cluster-1 --num-nodes=3 \
		--project $(PROJECT) --zone=$(ZONE) \
		--cluster-version 1.9.7-gke.0 \
		--node-version 1.9.7-gke.0 \
		--machine-type f1-micro \
		--no-enable-autorepair \
		--no-enable-autoscaling \
		--no-enable-autoupgrade \
		--no-enable-cloud-monitoring \
		--no-enable-cloud-logging \
		--addons NetworkPolicy
	$(MAKE) helm cluster-creds authenticate-helm chart YES=true
	$(HELM) init --upgrade
	kubectl replace --force -f scripts/limit-range.yaml
	scripts/fix-limits.sh
	$(MAKE) cluster-scale SIZE=1
	$(MAKE) helm-upgrade

cluster-down:
	gcloud container clusters delete cluster-1 --project $(PROJECT) --zone=$(ZONE) || true


