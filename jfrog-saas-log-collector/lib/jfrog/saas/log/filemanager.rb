# frozen_string_literal: true

require_relative "confighandler"

module Jfrog
  module Saas
    module Log
      class FileManager
        PROCESS_NAME = "log_file_purge"
        def check_and_create_dir(solution, target_path)
          sol_tgt_path = "#{target_path}/#{solution}"
          unless File.directory?(sol_tgt_path)
            FileUtils.mkdir_p(sol_tgt_path, verbose: ConfigHandler.instance.log_config.debug_mode)
          end
          sol_tgt_path
        end

        def purge_data
          Dir["#{ConfigHandler.instance.log_config.target_log_path}/**/*.log"].reject { |i| File.directory?(i) }.each do |file_name|
            created_time = File.ctime(file_name)
            diff_days = created_time.to_date.mjd - (Date.today - ConfigHandler.instance.log_config.log_file_retention_days).mjd
            CommonUtils.instance.log_msg(FileManager::PROCESS_NAME, "File #{file_name} has time of #{diff_days} days to be retained", CommonUtils::LOG_INFO)
            if diff_days.negative?
              File.delete(file_name)
              CommonUtils.instance.log_msg(FileManager::PROCESS_NAME, "File #{file_name} purged successfully", CommonUtils::LOG_INFO)
            end
          end
        end
      end
    end
  end
end
