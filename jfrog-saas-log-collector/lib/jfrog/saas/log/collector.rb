# frozen_string_literal: true

require 'English'
require "rufus/scheduler"
require "parallel"
require "json"
require "json-schema"

require_relative "collector/version"
require_relative "confighandler"
require_relative "commonutils"
require_relative "filemanager"
require_relative "constants"

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
              target_audit_repo_dir = "#{mapped_solution}/#{mapped_date}"
              target_audit_repo_exists = CommonUtils.instance.check_create_tgt_dir(solution, target_audit_repo_dir)
              if target_audit_repo_exists
                MessageUtils.instance.log_message(MessageUtils::FILE_DOWNLOAD_URL_AND_SIZE, { "param1": url.to_s,
                                                                                              "param2": CommonUtils.instance.get_size_in_mb(file_details["size"].to_i, true).to_s,
                                                                                              "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                              "#{MessageUtils::SOLUTION}": solution })
                CommonUtils.instance.download_and_extract_log(solution, mapped_date, ConfigHandler.instance.log_config.target_log_path, file_name, url)
              else
                MessageUtils.instance.log_message(MessageUtils::AUDIT_FILE_CREATION_FAILED, { "param1": "#{audit_repo_target_dir_url("#{mapped_solution}/#{mapped_date}", false, true, false)}/#{file_name}",
                                                                                              "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                              "#{MessageUtils::SOLUTION}": solution })
              end
            end
          end
        end

        def execute
          MessageUtils.instance.log_message(MessageUtils::APPLICATION_START, { "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO, "#{MessageUtils::SOLUTION}": "START" })

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
                                                                                 "#{MessageUtils::SOLUTION}": "START" })
            Parallel.map(ConfigHandler.instance.log_config.solutions_enabled, in_processes: ConfigHandler.instance.proc_config.parallel_process) do |solution|
              logs_to_process = process_logs(solution, start_date_str, end_date_str)
              download_and_extract_logs(solution, logs_to_process)
            end
          elsif !log_shipping_enabled
            MessageUtils.instance.log_message(MessageUtils::LOG_SHIPPING_NOT_ENABLED, { "param1": ConfigHandler.instance.conn_config.jpd_url.to_s,
                                                                                        "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                        "#{MessageUtils::SOLUTION}": "INIT" })
          elsif log_shipping_enabled && !log_repo_found
            MessageUtils.instance.log_message(MessageUtils::LOG_SHIPPING_ENABLED_LOGS_NOT_COLLECTABLE, { "param1": ConfigHandler.instance.conn_config.jpd_url.to_s,
                                                                                                         "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                                         "#{MessageUtils::SOLUTION}": "INIT" })
          elsif !audit_repo_found
            MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_NOT_FOUND_APPLICATION_STOP, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url}",
                                                                                                     "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                     "#{MessageUtils::SOLUTION}": "INIT" })
          else
            MessageUtils.instance.log_message(MessageUtils::INIT_FAILED_APPLICATION_STOP, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url}",
                                                                                            "param2": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url}",
                                                                                            "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                            "#{MessageUtils::SOLUTION}": "INIT" })
          end
          MessageUtils.instance.log_message(MessageUtils::APPLICATION_STOP, { "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO, "#{MessageUtils::SOLUTION}": "STOP" })
        end

        def execute_in_timer
          scheduler = Rufus::Scheduler.new
          scheduler.every "#{ConfigHandler.instance.proc_config.minutes_between_runs}m", first_in: 1 do
            execute
            next_execution_time = "#{(Time.now + (ConfigHandler.instance.proc_config.minutes_between_runs * 60)).getutc.strftime("%Y-%m-%d %H:%M:%S.%3N ")}#{Time.now.getutc.zone}"
            MessageUtils.instance.log_message(MessageUtils::SCHEDULER_NEXT_RUN, { "param1": next_execution_time,
                                                                                  "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                  "#{MessageUtils::SOLUTION}": "NEXT_RUN" })
          end
          scheduler.join
        end
      end

      class SchemaValidator
        include Singleton
        def validate(config_file)
          config_valid = false
          config_file_yaml = YAML.load_file(config_file)
          config_in_json = config_file_yaml.to_json
          config_schema_file = File.open((File.join(File.dirname(__FILE__), "config.template.schema.json")))
          config_schema = JSON.parse(config_schema_file.read)
          begin
            JSON::Validator.validate!(config_schema, config_in_json)
            config_valid = true
          rescue JSON::Schema::ValidationError
            puts "Config File Validation failed, reason -> #{$ERROR_INFO.message}"
          end
          config_valid
        end
      end

      module Collector
        config_path = nil
        begin
          OptionParser.new do |parser|
            parser.banner = "Usage: jfrog-saas-log-collector [options]"

            parser.on("-c", "--config=CONFIG", String) do |file|
              config_file_yaml = YAML.parse(File.open(file))
              if SchemaValidator.instance.validate(file)
                puts "#{file} \e[32mValid YAML\e[0m"
                config_path = file
              else
                puts "Config file provided #{file} is an \e[31mInvalid YAML file\e[0m, terminating jfrog-saas-log-collector operation "
                exit
              end
            rescue StandardError
              puts "Config file provided #{file} is an \e[31mInvalid YAML file\e[0m, terminating jfrog-saas-log-collector operation "
              exit
            end

            parser.on("-h", "--help", "Prints this help") do
              puts parser
              exit
            end

            parser.on("-g", "--generate=CONFIG", "Generates sample config file from template to target file provided") do |target_file|
              target_file = "jfrog-saas-log-collector-config.yaml" if target_file.nil?
              template = File.open(File.join(File.dirname(__FILE__), "config.template.yaml"))
              template_data = template.read
              File.open(target_file, "w") { |file| file.write(template_data) unless template_data.nil? }
              template.close
              puts "Config file from template written successfully to #{target_file}, modify necessary values before use"
              exit
            end
          end.parse!
        rescue OptionParser::ParseError => e
          puts "Received an\e[31m #{e} \e[0m, use -h or --help flag to list valid options, terminating jfrog-saas-log-collector operation "
          exit 1
        end


        # Terminate Main Thread Gracefully
        Signal.trap("TERM") do
          puts "\nShutting down process #{Process.pid}, terminating jfrog-saas-log-collector operation"
          sleep 1
          exit
        end

        Signal.trap("INT") do
          puts "\nShutting down process #{Process.pid}, terminating jfrog-saas-log-collector operation"
          sleep 1
          exit
        end

        # Run the program
        if config_path.nil?
          puts "\nNo config file provided, use -c option for config file path or provide the path in LOG_COLLECTOR_CONFIG environment variable, shutting down process #{Process.pid}, terminating jfrog-saas-log-collector operation"
        else
          Processor.new(config_path).execute_in_timer
        end
      end
    end
  end
end
