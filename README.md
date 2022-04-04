# Jfrog::Saas::Log::Collector

JFrog Saas Log Collector gem is intended for downloading and extracting of log files generated in Artifactory or Xray on the Jfrog Cloud.
The Log Collection feature on the cloud instance has to be [enabled](https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API#ArtifactoryRESTAPI-EnableLogCollection) for this gem to perform the download and extract of the logs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jfrog-saas-log-collector'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install jfrog-saas-log-collector

## Usage

Once the gem is successfully installed, use the gem to generate the sample config file,

    $ jfrog-saas-log-collector -g <full_path_of_the_config_file>

example

    $  jfrog-saas-log-collector -g /var/opt/jfrog/saas/sampleconfig.yaml

The config file sample would look like this, 

```yaml
connection:
  jpd_url: "<saas_jpd_url>"
  end_point_base: "artifactory"
  username: "<admin_user>"
  access_token: "<admin_access_token>"
  api_key: "<api_key_optional>"
  open_timeout_in_secs: 20
  read_timeout_in_secs: 60
log:
  log_ship_config: "access/api/v1/logshipping/config"
  solutions_enabled: "artifactory, xray"
  log_types_enabled: "access-request, router-request"
  uri_date_pattern: "%Y-%m-%d"
  audit_repo: "artifactory/jfrog-logs-audit"
  log_repo: "artifactory/jfrog-logs"
  debug_mode: false
  target_log_path: "<path_to_extract_logs_for_artifactory>"
  print_with_utc: false
  log_file_retention_days: 5
process:
  parallel_process: 2
  parallel_downloads: 5
  historical_log_days: 2
  write_logs_by_type: false
  minutes_between_runs: 180

```
Provide all the necessary values to the tags which have angular braces like "<saas_jpd_url>" to "https://example.jfrog.io", fill in for all other segments. Do not change any other values unless the operation associated with the other tag is understood well.
Once done, the jfrog-saas-log collector execution can be started by executing the command

    $ jfrog-saas-log-collector -c <full_path_of_the_config_file>

example

    $  jfrog-saas-log-collector -c /var/opt/jfrog/saas/sampleconfig.yaml

The gem records the progress or errors on the STDOUT / console and in a logfile (if the config provided is valid) which can be located at  <path_to_extract_logs_for_artifactory>/jfrog-saas-collector.log

For all the options supported use

    $ jfrog-saas-log-collector -h      OR    $ jfrog-saas-log-collector --help

```shell
Usage: jfrog-saas-log-collector [options]
    -h, --help                       Prints this help
    -g, --generate=CONFIG            Generates sample config file from template to target file provided
    -c, --config=CONFIG              Executes the jfrog-saas-log-collector with the config file provided
```

## Contributing

Bug reports are welcome on GitHub at https://github.com/jfrog/jfrog-fluentd-plugins/issues.

