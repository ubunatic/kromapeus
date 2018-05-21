.PHONY: vars clean all j2

# User vars
# =========
APP      = http-server
APPS     = http-server extra-server
SERVICES = grafana prometheus $(APPS)

COMPOSE_PREFIX = $(shell basename $(CURDIR))
DOCKEREXPR     = $(patsubst %,-e '$(COMPOSE_PREFIX)_%',$(SERVICES))
SOURCE         = app images $(PROM_YML).j2 Makefile docker-compose.yml
CONTAINERS     = $(shell docker ps --format "{{.Names}}" | grep $(DOCKEREXPR))
# vars used in docker-compose.yml
VARS = _REG=$(REGISTRY) _PRJ=$(PROJECT) _APP=${APP} _TAG=v0.0.1
COMPOSE = $(VARS) docker-compose


all: clean j2 run
clean: down
	rm -f $(PROM_YML)

j2: j2-prom ; # put extra templating code here

vars:
	# SOURCE:      $(SOURCE)
	#
	# SERVICES:    $(SERVICES)
	# APPS:        $(APPS)
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


# Docker Compose and K8S Kompose Tasks
# ====================================
.PHONY: up down build kill logs flush ping watch

up:    ; $(COMPOSE) up -d
down:  ; $(COMPOSE) down || $(MAKE) kill
run: up
	# test if all services are up
	sleep 5; $(MAKE) vars logs ping
	# Kromapeus stack started!

build: $(SOURCES) j2; $(COMPOSE) build
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

# Note: vars for dynamic targets (CHARTS), must be setup before include
include kompose.mk
