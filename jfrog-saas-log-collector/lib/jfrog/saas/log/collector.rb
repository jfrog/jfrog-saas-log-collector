# frozen_string_literal: true

require "parallel"

require_relative "collector/version"
require_relative "confighandler"
require_relative "commonutils"

module Jfrog
  module Saas
    module Log

      class Processor
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
          logs_map&.each do |date, file_map|
            file_map&.each do |file_name, file_details|
              url = "#{ConfigHandler.instance.conn_config.end_point_base}/#{file_details["repo"]}/#{file_details["path"]}/#{file_details["name"]}"
              date_detail = date.split(CommonUtils::DELIM)
              CommonUtils.instance.print_msg(solution, "Executing log download for #{date_detail[0]} solution logs for date #{date_detail[1]}")
              CommonUtils.instance.print_msg(solution, "Downloading log #{url} of size #{CommonUtils.instance.get_size_in_mb(file_details["size"].to_i, true)}")
              CommonUtils.instance.download_and_extract_log(solution, ConfigHandler.instance.log_config.target_log_path, file_name, url, nil)
            end
          end
        end

      end

      module Collector
        cfg = ConfigHandler.instance
        log_shipping_enabled = CommonUtils.instance.log_shipping_enabled
        log_repo_found = CommonUtils.instance.check_if_resource_exists(CommonUtils.instance.log_repo_url)
        audit_repo_found = CommonUtils.instance.check_and_create_audit_repo

        if log_shipping_enabled && log_repo_found && audit_repo_found
          CommonUtils.instance.print_msg(nil, "Resource #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url} and audit log repo  #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} found, proceeding with jfrog-saas-log-collector operation")
          Parallel.map(cfg.log_config.solutions_enabled, in_processes: cfg.proc_config.parallel_downloads) do |solution|
            proc = Processor.new
            logs = proc.process_logs(solution, (Date.today - cfg.proc_config.historical_log_days).to_s, Date.today.to_s)
            proc.download_and_extract_logs(solution, logs)
          end
        elsif !log_shipping_enabled
          CommonUtils.instance.print_msg(nil, "Log collection is not enabled for #{ConfigHandler.instance.conn_config.jpd_url}, please contact JFrog Support to enable log collection, terminating jfrog-saas-log-collector operation")
        elsif log_shipping_enabled && !log_repo_found
          CommonUtils.instance.print_msg(nil, "Log collection is enabled for #{ConfigHandler.instance.conn_config.jpd_url}, please wait for 24 hours if enabled recently for logs to be collected, terminating jfrog-saas-log-collector operation")
        elsif !audit_repo_found
          CommonUtils.instance.print_msg(nil, "Resource Audit log repo  #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} is not found, terminating jfrog-saas-log-collector operation")
        else
          CommonUtils.instance.print_msg(nil, "Resource #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url} not found <OR> audit log repo  #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} is not found, terminating jfrog-saas-log-collector operation")
        end
      end
    end
  end
end
