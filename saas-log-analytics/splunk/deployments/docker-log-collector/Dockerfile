# Dockerfile for jfrog-saas-log-collector image with all the necessary plugins for our log download, extract and load to target observability platform
FROM ruby:2.7.5-alpine3.15
LABEL maintainer="Partner Engineering <partner_support@jfrog.com>"

RUN apk update && apk add --no-cache build-base

## Install JFrog Saas Log Collector Gem
RUN gem install tzinfo
RUN gem install tzinfo-data
RUN gem install jfrog-saas-log-collector
RUN mkdir -p /jfrog/saas/
RUN jfrog-saas-log-collector -g /jfrog/saas/saas-config.yaml

ENTRYPOINT sed -i -e "s/HEC_HOST/$HEC_HOST/g" \
                                             -e "s/<saas_jpd_url>/$saas_jpd_url/g" \
                                             -e "s/<admin_user>/$admin_user/" \
                                             -e "s/<path_to_extract_logs_for_artifactory>/$path_to_extract_logs_for_artifactory/" \
                                             -e "s/solutions_enabled:.*/solutions_enabled: $solutions_enabled/" \
                                             -e "s/log_types_enabled:.*/log_types_enabled: $log_types_enabled/" \
                                             -e "s/print_with_utc:.*/print_with_utc: $print_with_utc/" \
                                             -e "s/write_logs_by_type:.*/write_logs_by_type: $write_logs_by_type/" \
                                             -e "s/historical_log_days:.*/historical_log_days: $historical_log_days/" \
                                             -e "s/log_file_retention_days:.*/log_file_retention_days: $log_file_retention_days/" \
                                             -e "s/<admin_access_token>/$admin_access_token/g" /jfrog/saas/saas-config.yaml && jfrog-saas-log-collector -c /jfrog/saas/saas-config.yaml;

STOPSIGNAL SIGTERM