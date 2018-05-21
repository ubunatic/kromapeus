.PHONY: vars clean all kompose

include kompose.mk

COMPOSE_PREFIX = $(shell basename $(CURDIR))
DOCKERNAMES = grafana prometheus http-server
DOCKEREXPR  = $(patsubst %,-e '$(COMPOSE_PREFIX)_%',$(DOCKERNAMES))
SOURCE      = app images
CONTAINERS  = $(shell docker ps --format "{{.Names}}" | grep $(DOCKEREXPR))
# vars used in docker-compose.yml
VARS = _REG=$(REGISTRY) _PRJ=$(PROJECT)

all: clean run
clean: down

vars:
	# SOURCE:      $(SOURCE)
	#
	# DOCKERNAMES: $(DOCKERNAMES)
	# DOCKEREXPR:  $(DOCKEREXPR)
	# CONTAINERS:  $(CONTAINERS)
	#
	# PATH:        $(PATH)
	# VARS:        $(VARS)
	#
	# Usage
	# -----
	# make up    # starts the containers
	# make down  # kills the containers

kompose: ; which kompose || go get -u github.com/kubernetes/kompose


# Docker Compose and K8S Kompose Tasks
# ====================================
.PHONY: up down build kill logs flush ping watch


chart: ; rm -rf chart; $(VARS) kompose convert -c -o chart
up:    ; $(VARS) docker-compose up -d
down:  ; $(VARS) docker-compose down || $(MAKE) kill
run: up
	# test if all services are up
	sleep 5; $(MAKE) vars logs ping
	# Kromapeus stack started!

SOURCES = docker-compose.yml images Dockerfile app
build: $(SOURCES); $(VARS) docker-compose build
kill:  ; test -z "$(CONTAINERS)" || docker rm -f $(CONTAINERS)
logs:  ; @$(patsubst %,echo; docker logs % --tail 7;,$(CONTAINERS))

ping:
	# ping http-server: http://0.0.0.0:8080 ...
	@curl -s http://0.0.0.0:8080 | grep -q process_cpu
	# ping grafana:     http://0.0.0.0:3000 ...
	@curl -s http://0.0.0.0:3000 2> /dev/null | grep -q title
	# ping prometheus:  http://0.0.0.0:9090 ...
	@curl -s http://0.0.0.0:9090 | grep -q graph
	# OK: all servers reachable!

watch: ; watch make logs ping



