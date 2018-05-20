.PHONY: vars clean all

include kompose.mk

COMPOSE_PREFIX = $(shell basename $(CURDIR))
DOCKERNAMES = grafana prometheus http-server
DOCKEREXPR  = $(patsubst %,-e '$(COMPOSE_PREFIX)_%',$(DOCKERNAMES))
SOURCE      = app images
CONTAINERS  = $(shell docker ps --format "{{.Names}}" | grep $(DOCKEREXPR))

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
	#
	# Usage
	# -----
	# make up    # starts the containers
	# make down  # kills the containers

.PHONY: up down build kill logs flush ping urls watch

VARS = _REG=$(REGISTRY) _PRJ=$(PROJECT)
up:   ; $(VARS) docker-compose up -d
down: ; $(VARS) docker-compose down || $(MAKE) kill

run: up
	# test if all services are up
	sleep 5; $(MAKE) vars logs ping urls
	# Kromapeus stack started!

urls:
	# Grafana:    http://0.0.0.0:3000
	# Prometheus: http://0.0.0.0:9090
	# App:        http://0.0.0.0:8080

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
