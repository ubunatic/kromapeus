.PHONY: kompose example all

export PATH := $(PATH):$(CURDIR)/bin

MINIKUBE_URL = https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

all: bin/minikube kompose

bin/minikube:
	mkdir -p bin
	curl -Lo bin/minikube $(MINIKUBE_URL)
	chmod +x bin/minikube
	# TODO (uj): let minikube run in docker to avoid sudo

example: data/examples/docker-compose.yaml
	kompose up $^
data/examples/docker-compose.yaml:
	dir=`dirname $@` && mkdir -p $$dir && cd $$dir && \
		 wget https://raw.githubusercontent.com/kubernetes/kompose/master/examples/docker-compose.yaml

kompose:
	which kompose || go get -u github.com/kubernetes/kompose
