# frozen_string_literal: true

require "zlib"
require "stringio"

require_relative "commonutils"
require_relative "filemanager"

module Jfrog
  module Saas
    module Log
      class Unzip
        def extract(solution, source_file, target_path, target_file_name, gzip_content)
          file_mgr = FileManager.new
          sol_tgt_path = file_mgr.check_and_create_dir(solution, target_path)
          unless gzip_content.nil?
            File.open("#{sol_tgt_path}/#{target_file_name}", "a") do |fp|
              fp.write(Zlib::GzipReader.new(StringIO.new(gzip_content)).read)
            end
            CommonUtils.instance.log_msg(solution, "Extracted log #{source_file} successfully written the content to #{sol_tgt_path}/#{target_file_name}", CommonUtils::LOG_INFO)
          end
        end
      end
    end
  end
end
