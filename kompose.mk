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

# reduce the limits of new pods thus we can run even on single node cluster
cluster-defaults:
	kubectl replace --force -f scripts/limit-range.yaml --namespace default

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

authenticate-helm:
	read -p "allow helm to adminster cluster using default service account? (y|N)" key; \
		test "$$key" != "y" || kubectl create clusterrolebinding add-on-cluster-admin \
		--clusterrole=cluster-admin --serviceaccount=kube-system:default

# recreate all chart from compose file
chart:
	_REG=$(REGISTRY) _PRJ=$(PROJECT) kompose convert -c -o chart

docker-auth: ; gcloud auth configure-docker

# targets for manually pusing images (kompose -c --build local will do this automatically)
PUSH_TARGETS = $(patsubst %,push-%,$(IMAGES))
push: $(PUSH_TARGETS)
$(PUSH_TARGETS): push-%: docker-auth ; docker push $*

# upgrade images, chart, and deployment
upgrade: build push chart
	bin/helm version  # run make helm if helm is not installed

POD = $(shell kubectl get pod --selector="io.kompose.service=$(SERVICE)" -o jsonpath='{.items[0].metadata.name}')
SERVICE = prometheus
PORTS = 8081:9090
cluster-forward:
	@echo creating '$(SERVICE)' service forward from http://0.0.0.0:$(subst :, to ,$(PORTS)) > /dev/stderr
	kubectl port-forward $(POD) $(PORTS)

cluster-forwards:
	bash -i -o errexit -c ' \
	$(MAKE) cluster-forward SERVICE=prometheus  PORTS=9091:9090 & \
	$(MAKE) cluster-forward SERVICE=grafana     PORTS=3001:3000 & \
	$(MAKE) cluster-forward SERVICE=http-server PORTS=8081:8080 & \
	wait'

helm-clean:
	rm -rf bin/helm scripts/get_helm.sh chart

