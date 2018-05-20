FROM grafana/grafana:5.1.3

ADD provisioning /etc/grafana/provisioning
ADD dashboards   /etc/grafana/dashboards

# create volume dir in case we run without volume
RUN mkdir -p /var/lib/grafana
