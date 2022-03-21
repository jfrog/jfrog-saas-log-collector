# frozen_string_literal: true

require_relative "collector/version"
require_relative "confighandler"
require_relative "connectionmanager"

module Jfrog
  module Saas
    module Log

      class Processor
        def process_logs(solution, start_date_str, end_date_str)
          logs = {}
          dates = CommonUtils.instance.logs_to_process_between(start_date_str, end_date_str)
          dates.each do |date|
            logs_to_process = CommonUtils.instance.logs_to_process_hash(solution, date)
            logs["#{solution}_@@_#{date}"] = logs_to_process
          end
        end
      end

      module Collector
        cfg_handler = ConfigHandler.instance
        proc = Processor.new
        logs = proc.process_logs("artifactory", "2022-03-11", "2022-03-21")
      end

    end
  end
end
