# frozen_string_literal: true

require "optparse"
require "yaml"
require "singleton"

require_relative "commonutils"

module Jfrog
  module Saas
    module Log
      class ConnectionConfig
        include Singleton

        jpd_url = ""
        end_point_base = ""
        username = ""
        access_token = ""
        api_key = ""
        ignore_errors_in_response = false

        def self.jpd_url
          jpd_url
        end

        def self.end_point_base
          end_point_base
        end

        def self.username
          username
        end

        def self.access_token
          access_token
        end

        def self.api_key
          api_key
        end

        def self.ignore_errors_in_response
          ignore_errors_in_response
        end

        attr_accessor :jpd_url, :end_point_base, :username, :access_token, :api_key, :ignore_errors_in_response

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          self.jpd_url = (config["connection"]["jpd_url"]).to_s
          self.username = (config["connection"]["username"]).to_s
          self.access_token = (config["connection"]["access_token"]).to_s
          self.end_point_base = (config["connection"]["end_point_base"]).to_s
          self.api_key = (config["connection"]["api_key"]).to_s
          self.ignore_errors_in_response = (config["connection"]["ignore_errors_in_response"])
        end

        def to_s
          "Object_id :#{object_id}, jpd_url :#{jpd_url}, username:#{username}, access_token: #{access_token}, end_point_base:#{end_point_base}, api_key:#{api_key}"
        end
      end

      class LogConfig
        include Singleton
        solutions_enabled = []
        log_types_enabled = []
        uri_date_pattern = ""
        audit_repo_url = ""
        log_repo_url = ""
        debug_mode = false

        def self.solutions_enabled
          solutions_enabled
        end

        def self.log_types_enabled
          log_types_enabled
        end

        def self.uri_date_pattern
          uri_date_pattern
        end

        def self.audit_repo_url
          audit_repo_url
        end

        def self.log_repo_url
          log_repo_url
        end

        def self.debug_mode
          debug_mode
        end

        attr_accessor :solutions_enabled, :log_types_enabled, :uri_date_pattern, :audit_repo_url, :log_repo_url, :debug_mode

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          self.solutions_enabled = config["log"]["solutions_enabled"].split(",")
          self.log_types_enabled = config["log"]["log_types_enabled"].split(",")
          self.uri_date_pattern = (config["log"]["uri_date_pattern"]).to_s
          self.audit_repo_url = (config["log"]["audit_repo"]).to_s
          self.log_repo_url = (config["log"]["log_repo"]).to_s
          self.debug_mode = (config["log"]["debug_mode"])
        end

        def to_s
          "Object_id :#{object_id}, solutions_enabled :#{solutions_enabled}, log_types_enabled:#{log_types_enabled}, uri_date_pattern: #{uri_date_pattern}"
        end

      end

      class ProcessConfig
        include Singleton
        target_jfrt_path = ""
        target_jfxr_path = ""
        parallel_downloads = 10

        def self.target_jfrt_path
          target_jfrt_path
        end

        def self.target_jfxr_path
          target_jfxr_path
        end

        def self.parallel_downloads
          parallel_downloads
        end

        attr_accessor :target_jfrt_path, :target_jfxr_path, :parallel_downloads

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          self.target_jfrt_path = (config["process"]["target_jfrt_path"]).to_s
          self.target_jfxr_path = (config["process"]["target_jfxr_path"]).to_s
          self.parallel_downloads = config["process"]["parallel_downloads"]
        end

        def to_s
          "Object_id :#{object_id}, target_jfrt_path :#{target_jfrt_path}, target_jfxr_path:#{target_jfxr_path}, parallel_downloads: #{parallel_downloads}"
        end

      end

      class ConfigHandler
        include Singleton
        @conn_config = nil
        @log_config = nil
        @proc_config = nil
        @config_path = nil

        class << self
          attr_reader :conn_config
        end

        class << self
          attr_reader :log_config
        end

        class << self
          attr_reader :proc_config
        end

        attr_accessor :conn_config, :log_config, :proc_config

        def initialize
          @mutex = Mutex.new
          # Check from Options
          OptionParser.new do |parser|
            parser.on("-c", "--config=CONFIG", String) do |file|
              puts "File Path is -> #{file}"
              @config_path = file
            end
          end.parse!
          # If not found in options, check for the environment variable
          @config_path = ENV["LOG_COLLECTOR_CONFIG"] if @config_path.nil?
          # If not found in environment variable, look for current path
          @config_path = "config.yaml" if @config_path.nil?
          load_all_config(@config_path, "initialize")
        end

        def load_all_config(config_file, thread_name)
          @mutex.synchronize do
            if !config_file.nil?
              CommonUtils.instance.print_msg("#{thread_name} - Config Start")
              @conn_config = ConnectionConfig.instance
              @conn_config.configure(config_file, thread_name)
              @log_config = LogConfig.instance
              @log_config.configure(config_file, thread_name)
              @proc_config = ProcessConfig.instance
              @proc_config.configure(config_file, thread_name)

              if LogConfig.instance.debug_mode == true
                CommonUtils.instance.print_msg("#{thread_name} - Connection Configuration : #{@conn_config}")
              end
              if LogConfig.instance.debug_mode == true
                CommonUtils.instance.print_msg("#{thread_name} - Logging Configuration : #{@log_config}")
              end
              if LogConfig.instance.debug_mode == true
                CommonUtils.instance.print_msg("#{thread_name} - Processor Configuration : #{@proc_config}")
              end
              CommonUtils.instance.print_msg("#{thread_name} - Config End")
            else
              CommonUtils.instance.print_msg("No Config file provided")
            end
          end
        end
      end
    end
  end
end
