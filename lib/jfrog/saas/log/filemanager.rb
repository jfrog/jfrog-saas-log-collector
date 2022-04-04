# frozen_string_literal: true

require_relative 'confighandler'
require_relative 'constants'

module Jfrog
  module Saas
    module Log
      class FileManager
        PROCESS_NAME = 'log_file_purge'
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
            MessageUtils.instance.log_message(MessageUtils::PURGE_RETAIN_DAYS_FOR_FILE, { "param1": file_name.to_s,
                                                                                          "param2": diff_days.to_s,
                                                                                          "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                          "#{MessageUtils::SOLUTION}": FileManager::PROCESS_NAME } )
            next unless diff_days.negative?

            File.delete(file_name)
            MessageUtils.instance.log_message(MessageUtils::PURGE_SUCCESS_FOR_FILE, { "param1": file_name.to_s,
                                                                                      "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                      "#{MessageUtils::SOLUTION}": FileManager::PROCESS_NAME } )
          end
        end
      end
    end
  end
end
