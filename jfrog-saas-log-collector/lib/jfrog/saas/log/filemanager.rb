# frozen_string_literal: true

require_relative "confighandler"

module Jfrog
  module Saas
    module Log
      class FileManager
        def check_and_create_dir(solution, target_path)
          sol_tgt_path = "#{target_path}/#{solution}"
          unless File.directory?(sol_tgt_path)
            FileUtils.mkdir_p(sol_tgt_path, verbose: ConfigHandler.instance.log_config.debug_mode)
          end
          sol_tgt_path
        end
      end
    end
  end
end
