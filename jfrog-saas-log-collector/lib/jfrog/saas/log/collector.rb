# frozen_string_literal: true

require "rufus/scheduler"
require "parallel"

require_relative "collector/version"
require_relative "confighandler"
require_relative "commonutils"
require_relative "filemanager"

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
              target_audit_repo_exists = CommonUtils.instance.check_and_create_audit_repo_tgt_dir(solution, target_audit_repo_dir)
              if target_audit_repo_exists
                CommonUtils.instance.log_msg(solution, "Downloading log #{url} of size #{CommonUtils.instance.get_size_in_mb(file_details["size"].to_i, true)}", CommonUtils::LOG_INFO)
                CommonUtils.instance.download_and_extract_log(solution, mapped_date, ConfigHandler.instance.log_config.target_log_path, file_name, url)
              else
                CommonUtils.instance.log_msg(solution, "Audit File creation for #{audit_repo_target_dir_url("#{mapped_solution}/#{mapped_date}", false, true, false)}/#{file_name} failed", CommonUtils::LOG_ERROR)
              end
            end
          end
        end

        def execute
          CommonUtils.instance.log_msg("START", "jfrog-saas-log-collector operation started", CommonUtils::LOG_INFO)

          FileManager.new.purge_data

          log_shipping_enabled = CommonUtils.instance.log_shipping_enabled
          log_repo_found = CommonUtils.instance.check_if_resource_exists(nil, CommonUtils.instance.log_repo_url)
          audit_repo_found = CommonUtils.instance.check_and_create_audit_repo

          if log_shipping_enabled && log_repo_found && audit_repo_found
            start_date_str = (Date.today - ConfigHandler.instance.proc_config.historical_log_days).to_s
            end_date_str = Date.today.to_s
            CommonUtils.instance.log_msg(nil, "Resource #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url} and audit log repo  #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} found, proceeding with jfrog-saas-log-collector operation", CommonUtils::LOG_INFO)
            Parallel.map(ConfigHandler.instance.log_config.solutions_enabled, in_processes: ConfigHandler.instance.proc_config.parallel_process) do |solution|
              logs_to_process = process_logs(solution, start_date_str, end_date_str)
              download_and_extract_logs(solution, logs_to_process)
            end
          elsif !log_shipping_enabled
            CommonUtils.instance.log_msg(nil, "Log collection is not enabled for #{ConfigHandler.instance.conn_config.jpd_url}, please contact JFrog Support to enable log collection, terminating jfrog-saas-log-collector operation", CommonUtils::LOG_ERROR)
          elsif log_shipping_enabled && !log_repo_found
            CommonUtils.instance.log_msg(nil, "Log collection is enabled for #{ConfigHandler.instance.conn_config.jpd_url}, please wait for 24 hours if enabled recently for logs to be collected, terminating jfrog-saas-log-collector operation", CommonUtils::LOG_ERROR)
          elsif !audit_repo_found
            CommonUtils.instance.log_msg(nil, "Resource Audit log repo  #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} is not found, terminating jfrog-saas-log-collector operation", CommonUtils::LOG_ERROR)
          else
            CommonUtils.instance.log_msg(nil, "Resource #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url} not found <OR> audit log repo  #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} is not found, terminating jfrog-saas-log-collector operation", CommonUtils::LOG_ERROR)
          end
          CommonUtils.instance.log_msg("END", "jfrog-saas-log-collector operation ended", CommonUtils::LOG_INFO)
        end

        def execute_in_timer
          scheduler = Rufus::Scheduler.new
          scheduler.every "#{ConfigHandler.instance.proc_config.minutes_between_runs}m", first_in: 1 do
            execute
            next_execution_time = "#{(Time.now + (ConfigHandler.instance.proc_config.minutes_between_runs * 60)).getutc.strftime("%Y-%m-%d %H:%M:%S.%3N ")}#{Time.now.getutc.zone}"
            CommonUtils.instance.log_msg("NEXT_RUN", "jfrog-saas-log-collector operation will run next at #{next_execution_time}", CommonUtils::LOG_INFO)
          end
          scheduler.join
        end
      end

      module Collector
        config_path = nil
        OptionParser.new do |parser|
          parser.banner = "Usage: jfrog-saas-log-collector [options]"

          parser.on("-c", "--config=CONFIG", String) do |file|
            YAML.parse(File.open(file))
            puts "#{file} \e[32mValid YAML\e[0m"
            config_path = file
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
            exit
          end
        end.parse!

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
