# Dockerfile for bitnami/fluentd sidecar image with all the necessary plugins for our log analytic providers
FROM bitnami/fluentd:latest
LABEL maintainer="Partner Engineering <partner_support@jfrog.com>"

USER root

## Install custom Fluentd plugins
RUN fluent-gem install fluent-plugin-splunk-hec --no-doc

## Download Config Files
RUN echo "Downloading the fluentd config file"; 
RUN curl https://raw.githubusercontent.com/jfrog/jfrog-saas-log-collector/main/saas-log-analytics/splunk/fluentd-config/fluent.conf.saas.rt -o /opt/bitnami/fluentd/conf/fluentd.conf;

ENTRYPOINT fluentd -c /opt/bitnami/fluentd/conf/fluentd.conf

USER 1001

STOPSIGNAL SIGTERM