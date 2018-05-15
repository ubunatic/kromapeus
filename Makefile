.PHONY: vars clean all

include kompose.mk

DOCKERNAMES = grafana prometheus http-server
DOCKEREXPR  = $(patsubst %,-e 'compose_%',$(DOCKERNAMES))
DATAVOLUMES = $(addprefix data/, $(DOCKERNAMES))

SOURCE     = app etc
CONTAINERS = $(shell docker ps --format "{{.Names}}" | grep $(DOCKEREXPR))

all: clean .vol run vars
clean: kill ; rm -rf .vol

vars:
	# SOURCE:      $(SOURCE)
	#
	# DOCKERNAMES: $(DOCKERNAMES)
	# DOCKEREXPR:  $(DOCKEREXPR)
	# CONTAINERS:  $(CONTAINERS)
	# DATAVOLUMES: $(DATAVOLUMES)
	#
	# PATH:        $(PATH)
	#
	# Usage
	# -----
	# make run   # starts the containers
	# make kill  # kills the containers

.vol: $(SOURCE);
	# creating temporary script and config volumes...
	mkdir -p $@
	rsync -a $(SOURCE) $@
	# these are safe to remove after the docker stack has stopped

$(DATAVOLUMES):
	# creating persitent data volumes...
	mkdir -p $@
	chmod 777 $@
	# these volumes store the data for the containers

.PHONY: run build kill logs flush ping

run: .vol $(DATAVOLUMES)
	docker-compose up -d

build: ; docker-compose build
kill:  ; test -z "$(CONTAINERS)" || docker rm -f $(CONTAINERS)
logs:  ; @$(patsubst %,echo; docker logs % --tail 10;,$(CONTAINERS))
flush: ; rm -rf $(DATAVOLUMES)

ping:
	# ping http-server...
	@curl -s http://0.0.0.0:8080 | grep -q process_cpu
	# ping grafana...
	@curl -s http://0.0.0.0:3000 2> /dev/null | grep -q title
	# ping prometheus...
	@curl -s http://0.0.0.0:9090 | grep -q graph
	# OK: all servers reachable!
