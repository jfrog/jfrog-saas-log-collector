# frozen_string_literal: true

require "parallel"

require_relative "collector/version"
require_relative "confighandler"
require_relative "connectionmanager"

module Jfrog
  module Saas
    module Log

      class Processor
        def process_logs(solution, start_date_str, end_date_str)
          logs = {}
          dates = CommonUtils.instance.logs_to_process_between(solution, start_date_str, end_date_str)
          dates.each do |date|
            logs_to_process = CommonUtils.instance.logs_to_process_hash(solution, date)
            logs["#{solution}_@@_#{date}"] = logs_to_process
          end
          logs
        end

        def download_and_extract_logs(solution, logs_map)
          logs_map&.each do |date, file_map|
            file_map&.each do |file_name, file_details|
              CommonUtils.instance.print_msg(solution, "Executing log download for #{date.split("_@@_")[0]} solution logs for date #{date.split("_@@_")[1]}")
              url = "#{ConfigHandler.instance.conn_config.end_point_base}/#{file_details["repo"]}/#{file_details["path"]}/#{file_details["name"]}"
              CommonUtils.instance.print_msg(solution, "Downloading log #{url} of size #{(file_details["size"] / (1024.0 * 1024.0)).round(2) } MB")
              CommonUtils.instance.download_and_extract_log(solution, ConfigHandler.instance.log_config.target_log_path, file_name, url, nil)
            end
          end
        end

      end

      module Collector
        cfg_handler = ConfigHandler.instance
        Parallel.map(ConfigHandler.instance.log_config.solutions_enabled, in_processes: ConfigHandler.instance.proc_config.parallel_downloads) do |solution|
          proc = Processor.new
          logs = proc.process_logs(solution, (Date.today - 2).to_s, Date.today.to_s)
          proc.download_and_extract_logs(solution, logs)
        end
      end

    end
  end
end
