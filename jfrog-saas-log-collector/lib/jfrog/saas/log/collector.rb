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
              mapped_solution = date_detail[0]
              mapped_date = date_detail[1]
              target_audit_repo_dir = "#{mapped_solution}/#{mapped_date}"
              target_audit_repo_exists = CommonUtils.instance.check_and_create_audit_repo_tgt_dir(solution, target_audit_repo_dir)
              if target_audit_repo_exists
                CommonUtils.instance.log_msg(solution, "Executing log download for #{mapped_solution} solution logs for date #{mapped_date}", CommonUtils::LOG_INFO)
                CommonUtils.instance.log_msg(solution, "Downloading log #{url} of size #{CommonUtils.instance.get_size_in_mb(file_details["size"].to_i, true)}", CommonUtils::LOG_INFO)
                CommonUtils.instance.download_and_extract_log(solution, mapped_date, ConfigHandler.instance.log_config.target_log_path, file_name, url)
              else
                CommonUtils.instance.log_msg(solution, "Audit File creation for #{audit_repo_target_dir_url("#{mapped_solution}/#{mapped_date}", false, true, false)}/#{file_name} failed", CommonUtils::LOG_ERROR)
              end
            end
          end
        end

      end

      module Collector
        cfg = ConfigHandler.instance
        log_shipping_enabled = CommonUtils.instance.log_shipping_enabled
        log_repo_found = CommonUtils.instance.check_if_resource_exists(nil, CommonUtils.instance.log_repo_url)
        audit_repo_found = CommonUtils.instance.check_and_create_audit_repo

        if log_shipping_enabled && log_repo_found && audit_repo_found
          start_date_str = (Date.today - cfg.proc_config.historical_log_days).to_s
          end_date_str = Date.today.to_s
          CommonUtils.instance.log_msg(nil, "Resource #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.log_repo_url} and audit log repo  #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} found, proceeding with jfrog-saas-log-collector operation", CommonUtils::LOG_INFO)
          Parallel.map(cfg.log_config.solutions_enabled, in_processes: cfg.proc_config.parallel_downloads) do |solution|
            proc = Processor.new
            logs_to_process = proc.process_logs(solution, start_date_str, end_date_str)
            proc.download_and_extract_logs(solution, logs_to_process)
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

      end
    end
  end
end
