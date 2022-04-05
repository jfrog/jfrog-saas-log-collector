# frozen_string_literal: true

require 'English'
require 'rufus/scheduler'
require 'parallel'
require 'json'
require 'json-schema'
require 'addressable/uri'

require_relative 'collector/version'
require_relative 'confighandler'
require_relative 'commonutils'
require_relative 'filemanager'
require_relative 'constants'

module Jfrog
  module Saas
    module Log
      class Processor
        def initialize(config_path)
          ConfigHandler.file_name(config_path)
          ConfigHandler.instance
        end

        def process_logs(solution, start_date_str, end_date_str)
          logs = {}
          dates = CommonUtils.instance.logs_to_process_between(solution, start_date_str, end_date_str)
          dates.each do |date|
            logs_to_process = CommonUtils.instance.logs_to_process_hash(solution, date)
            logs["#{solution}#{CommonUtils::DELIM}#{date}"] = logs_to_process
          end
          logs
        end

        def download_and_extract_logs(solution, logs_map)
          Parallel.map(logs_map&.keys, in_threads: ConfigHandler.instance.proc_config.parallel_downloads) do |date_detail|
            date_detail_arr = date_detail.split(CommonUtils::DELIM)
            mapped_solution = date_detail_arr[0]
            mapped_date = date_detail_arr[1]
            file_map = logs_map[date_detail]
            file_map&.each do |file_name, file_details|
              url = "#{ConfigHandler.instance.conn_config.end_point_base}/#{file_details["repo"]}/#{file_details["path"]}/#{file_details["name"]}"
              MessageUtils.instance.log_message(MessageUtils::FILE_DOWNLOAD_URL_AND_SIZE, { "param1": url.to_s,
                                                                                            "param2": CommonUtils.instance.get_size_in_mb(file_details['size'].to_i, true).to_s,
                                                                                            "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                            "#{MessageUtils::SOLUTION}": solution })
              CommonUtils.instance.download_and_extract_log(solution, mapped_date, ConfigHandler.instance.log_config.target_log_path, file_name, url)
            end
          end
        end

        def execute
          MessageUtils.instance.log_message(MessageUtils::APPLICATION_START, { "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO, "#{MessageUtils::SOLUTION}": 'START' })

          FileManager.new.purge_data

          log_shipping_enabled = CommonUtils.instance.log_shipping_enabled
          log_repo_found = CommonUtils.instance.check_if_resource_exists(nil, CommonUtils.instance.log_repo_url)
          audit_repo_found = CommonUtils.instance.check_and_create_audit_repo

          if log_shipping_enabled && log_repo_found && audit_repo_found
            start_date_str = (Date.today - ConfigHandler.instance.proc_config.historical_log_days).to_s
            end_date_str = Date.today.to_s
            MessageUtils.instance.log_message(MessageUtils::INIT_VERIFICATION, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url}",
                                                                                 "param2": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url}",
                                                                                 "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                 "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_START })
            Parallel.map(ConfigHandler.instance.log_config.solutions_enabled, in_processes: ConfigHandler.instance.proc_config.parallel_process) do |solution|
              logs_to_process = process_logs(solution, start_date_str, end_date_str)
              download_and_extract_logs(solution, logs_to_process)
            end
          elsif !log_shipping_enabled
            MessageUtils.instance.log_message(MessageUtils::LOG_SHIPPING_NOT_ENABLED, { "param1": ConfigHandler.instance.conn_config.jpd_url.to_s,
                                                                                        "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                        "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT })
          elsif log_shipping_enabled && !log_repo_found
            MessageUtils.instance.log_message(MessageUtils::LOG_SHIPPING_ENABLED_LOGS_NOT_COLLECTABLE, { "param1": ConfigHandler.instance.conn_config.jpd_url.to_s,
                                                                                                         "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                                         "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT })
          elsif !audit_repo_found
            MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_NOT_FOUND_APPLICATION_STOP, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url}",
                                                                                                     "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                     "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT })
          else
            MessageUtils.instance.log_message(MessageUtils::INIT_FAILED_APPLICATION_STOP, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url}",
                                                                                            "param2": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url}",
                                                                                            "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                            "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT })
          end
          MessageUtils.instance.log_message(MessageUtils::APPLICATION_STOP, { "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO, "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_STOP })
        end

        def execute_in_timer
          scheduler = Rufus::Scheduler.new
          scheduler.every "#{ConfigHandler.instance.proc_config.minutes_between_runs}m", first_in: 1, overlap: false, name: 'jfrog-saas-log-collector-job' do |job|
            execute
            next_execution_time = job.next_time.to_s
            MessageUtils.instance.log_message(MessageUtils::SCHEDULER_NEXT_RUN, { "param1": next_execution_time,
                                                                                  "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                  "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_NEXT_RUN })
          end
          scheduler.join
        rescue Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::SSLError, Faraday::ServerError, Faraday::ConnectionFailed => e
          MessageUtils.instance.log_message(MessageUtils::SHUT_DOWN_PROCESS, { "param1": "#{Process.pid.to_s} [Reason -> #{e}]",
                                                                               "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                               "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
          Thread.list.each do |thread|
            MessageUtils.instance.log_message(MessageUtils::TERMINATING_THREAD, { "param1": thread.object_id.to_s,
                                                                                  "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                  "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
            Thread.kill thread
          end
          next_execution_time = (Time.now + (ConfigHandler.instance.proc_config.minutes_between_runs * 60)).strftime('%Y-%m-%d %H:%M').to_s
          MessageUtils.instance.log_message(MessageUtils::SCHEDULER_NEXT_RUN, { "param1": next_execution_time,
                                                                                "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_NEXT_RUN })
        end
      end

      class SchemaValidator
        include Singleton

        def jpd_whitelisted(jpd_url)
          whitelisted_domains_yaml = YAML.load_file(File.open(File.join(File.dirname(__FILE__), 'whitelisted_domains.yaml')))
          whitelisted_domains = whitelisted_domains_yaml['whitelist']['domains']
          uri = Addressable::URI.parse(jpd_url)
          if whitelisted_domains.include? uri.domain
            true
          else
            false
          end
        end

        def validate(config_file)
          config_valid = false
          config_file_yaml = YAML.load_file(config_file)
          config_in_json = config_file_yaml.to_json
          config_schema_file = File.open((File.join(File.dirname(__FILE__), 'config.template.schema.json')))
          config_schema = JSON.parse(config_schema_file.read)
          begin
            JSON::Validator.validate!(config_schema, config_in_json)
            jpd_url = (config_file_yaml['connection']['jpd_url']).to_s.strip
            if jpd_whitelisted(jpd_url)
              config_valid = true
            else
              MessageUtils.instance.put_message(MessageUtils::CONFIG_FILE_VALIDATION_FAILED_DETAILS, { "param1": "#{config_file.to_s} contains JPD URL which is not permitted",
                                                                                                   "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                   "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
              config_valid = false
            end
          rescue JSON::Schema::ValidationError
            MessageUtils.instance.put_message(MessageUtils::CONFIG_FILE_VALIDATION_FAILED_DETAILS, { "param1": $ERROR_INFO.message,
                                                                                                     "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                     "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
          end
          config_valid
        end


      end

      module Collector
        config_path = nil
        begin
          OptionParser.new do |parser|
            parser.banner = 'Usage: jfrog-saas-log-collector [options]'

            parser.on('-h', '--help', 'Prints this help') do
              puts parser
              exit 0
            end

            parser.on('-g', '--generate=CONFIG', 'Generates sample config file from template to target file provided') do |target_file|
              target_file = 'jfrog-saas-log-collector-config.yaml' if target_file.nil?
              target_file = target_file.strip
              template = File.open(File.join(File.dirname(__FILE__), 'config.template.yaml'))
              template_data = template.read
              File.open(target_file, 'w') { |file| file.write(template_data) unless template_data.nil? }
              template.close
              MessageUtils.instance.put_message(MessageUtils::CONFIG_TEMPLATE_SUCCESSFULLY_WRITTEN, { "param1": target_file.to_s,
                                                                                                      "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                                      "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT })
              exit 0
            end

            parser.on('-c', '--config=CONFIG', 'Executes the jfrog-saas-log-collector with the config file provided') do |file|
              file = file.strip
              YAML.parse(File.open(file))
              if SchemaValidator.instance.validate(file)
                MessageUtils.instance.put_message(MessageUtils::VALID_CONFIG_FILE_PROVIDED, { "param1": file.to_s,
                                                                                              "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                              "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT })
                config_path = file
              else
                MessageUtils.instance.put_message(MessageUtils::CONFIG_FILE_PROVIDED_IS_NOT_VALID, { "param1": file.to_s,
                                                                                                     "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                     "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
                exit 0
              end
            rescue StandardError
              MessageUtils.instance.put_message(MessageUtils::CONFIG_FILE_PROVIDED_IS_NOT_VALID, { "param1": file.to_s,
                                                                                                   "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                   "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
              exit 130
            end

          end.parse!
        rescue OptionParser::ParseError => e
          MessageUtils.instance.put_message(MessageUtils::RECEIVED_AN_INVALID_OPTION_FLAG, { "param1": e.to_s,
                                                                                             "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                             "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
          exit 130
        end

        def self.shutdown
          MessageUtils.instance.put_message(MessageUtils::SHUT_DOWN_PROCESS, { "param1": Process.pid.to_s,
                                                                               "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                               "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
          sleep 1
          Thread.list.each do |thread|
            MessageUtils.instance.put_message(MessageUtils::TERMINATING_THREAD, { "param1": thread.object_id.to_s,
                                                                                  "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                  "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_TERMINATE })
            Thread.kill thread
          end
          exit 130
        end

        # Terminate Main Thread Gracefully
        Signal.trap('TERM') do
          Collector.shutdown
        end

        Signal.trap('INT') do
          Collector.shutdown
        end

        # Run the program
        if config_path.nil?
          Collector.shutdown
        else
          Processor.new(config_path).execute_in_timer
        end
      end
    end
  end
end
