# frozen_string_literal: true

require 'zlib'
require 'stringio'

require_relative 'commonutils'
require_relative 'filemanager'
require_relative 'constants'

module Jfrog
  module Saas
    module Log
      class Unzip
        def extract(solution, source_file, target_path, target_file_name, gzip_content)
          file_mgr = FileManager.new
          sol_tgt_path = file_mgr.check_and_create_dir(solution, target_path)
          unless gzip_content.nil?
            File.open("#{sol_tgt_path}/#{target_file_name}", 'a') do |fp|
              fp.write(Zlib::GzipReader.new(StringIO.new(gzip_content)).read)
            end
            MessageUtils.instance.log_message(MessageUtils::EXTRACT_LOG_FILE_SUCCESS, { "param1": source_file.to_s,
                                                                                        "param2": "#{sol_tgt_path}/#{target_file_name}",
                                                                                        "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                        "#{MessageUtils::SOLUTION}": solution })
          end
        end
      end
    end
  end
end
