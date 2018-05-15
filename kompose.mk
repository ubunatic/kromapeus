MINIKUBE_URL = https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

export PATH := $(PATH):$(CURDIR)/bin

all: bin/minikube kompose

bin/minikube:
	mkdir -p bin
	curl -Lo bin/minikube $(MINIKUBE_URL)
	chmod +x bin/minikube

.PHONY: kompose
kompose:
	which kompose || go get -u github.com/kubernetes/kompose

