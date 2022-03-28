# frozen_string_literal: true

require "optparse"
require "yaml"
require "singleton"

require_relative "commonutils"

module Jfrog
  module Saas
    module Log
      class LogConfig
        include Singleton
        logger = nil
        console_logger = nil
        log_ship_config = ""
        solutions_enabled = []
        log_types_enabled = []
        uri_date_pattern = ""
        audit_repo_url = ""
        log_repo_url = ""
        target_log_path = ""
        debug_mode = false
        print_with_utc = false

        def self.logger
          logger
        end

        def self.console_logger
          console_logger
        end

        def self.log_ship_config
          log_ship_config
        end

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

        def self.target_log_path
          target_log_path
        end

        def self.print_with_utc
          print_with_utc
        end

        attr_accessor :solutions_enabled, :log_types_enabled, :uri_date_pattern, :audit_repo_url, :log_repo_url, :debug_mode, :target_log_path, :log_ship_config, :logger, :console_logger, :print_with_utc

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          self.target_log_path = (config["log"]["target_log_path"]).to_s.strip
          log_file = "#{target_log_path}/jfrog-saas-collector.log"

          self.logger = Logger.new(log_file, "weekly")
          self.console_logger = Logger.new($stdout)

          console_logger.formatter = logger.formatter = proc do |severity, datetime, progname, msg|
            date_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
            "[ #{date_format} pid=##{Process.pid} ] #{severity.ljust(5)} --  #{msg}\n"
          end

          self.log_ship_config = (config["log"]["log_ship_config"])
          self.solutions_enabled = config["log"]["solutions_enabled"].split(",").map(&:strip)
          self.log_types_enabled = config["log"]["log_types_enabled"].split(",").map(&:strip)
          self.uri_date_pattern = (config["log"]["uri_date_pattern"]).to_s
          self.audit_repo_url = (config["log"]["audit_repo"]).to_s.strip
          self.log_repo_url = (config["log"]["log_repo"]).to_s.strip
          self.debug_mode = (config["log"]["debug_mode"])
          self.print_with_utc = (config["log"]["print_with_utc"])
        end

        def to_s
          "Object_id :#{object_id}, solutions_enabled :#{solutions_enabled}, log_types_enabled:#{log_types_enabled}, uri_date_pattern: #{uri_date_pattern}"
        end

      end

      class ConnectionConfig
        include Singleton

        jpd_url = ""
        end_point_base = ""
        username = ""
        access_token = ""
        api_key = ""
        ignore_errors_in_response = false
        open_timeout_in_secs = 5
        read_timeout_in_secs = 60

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

        def self.open_timeout_in_secs
          open_timeout_in_secs
        end

        def self.read_timeout_in_secs
          read_timeout_in_secs
        end

        attr_accessor :jpd_url, :end_point_base, :username, :access_token, :api_key, :ignore_errors_in_response, :open_timeout_in_secs, :read_timeout_in_secs

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          self.jpd_url = (config["connection"]["jpd_url"]).to_s.strip
          self.username = (config["connection"]["username"]).to_s.strip
          self.access_token = (config["connection"]["access_token"]).to_s.strip # TODO: Check if the Strip is needed for access token, can spaces be at start and end of any token
          self.end_point_base = (config["connection"]["end_point_base"]).to_s.strip
          self.api_key = (config["connection"]["api_key"]).to_s.strip
          self.ignore_errors_in_response = (config["connection"]["ignore_errors_in_response"])
          self.open_timeout_in_secs = (config["connection"]["open_timeout_in_secs"])
          self.read_timeout_in_secs = (config["connection"]["read_timeout_in_secs"])
        end

        def to_s
          "Object_id :#{object_id}, jpd_url :#{jpd_url}, username:#{username}, access_token: #{access_token}, end_point_base:#{end_point_base}, api_key:#{api_key}"
        end
      end

      class ProcessConfig
        include Singleton
        parallel_downloads = 1
        historical_log_days = 1
        write_logs_by_type = false

        def self.parallel_downloads
          parallel_downloads
        end

        def self.historical_log_days
          historical_log_days
        end

        def self.write_logs_by_type
          write_logs_by_type
        end

        attr_accessor :parallel_downloads, :historical_log_days, :write_logs_by_type

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          self.parallel_downloads = config["process"]["parallel_downloads"].to_i
          self.historical_log_days = config["process"]["historical_log_days"].to_i
          self.write_logs_by_type = config["process"]["write_logs_by_type"]
        end

        def to_s
          "Object_id :#{object_id}, parallel_downloads: #{parallel_downloads}, historical_log_days: #{historical_log_days}, write_logs_by_type: #{write_logs_by_type}"
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
              @log_config = LogConfig.instance
              @log_config.configure(config_file, thread_name)
              @conn_config = ConnectionConfig.instance
              @conn_config.configure(config_file, thread_name)
              @proc_config = ProcessConfig.instance
              @proc_config.configure(config_file, thread_name)

              CommonUtils.instance.log_msg(nil, "#{thread_name} - Configuration Started, loading #{config_file}", CommonUtils::LOG_INFO)

              if LogConfig.instance.debug_mode == true
                CommonUtils.instance.log_msg(nil, "#{thread_name} - Connection Configuration : #{@conn_config}", CommonUtils::LOG_DEBUG)
              end
              if LogConfig.instance.debug_mode == true
                CommonUtils.instance.log_msg(nil, "#{thread_name} - Logging Configuration : #{@log_config}", CommonUtils::LOG_DEBUG)
              end
              if LogConfig.instance.debug_mode == true
                CommonUtils.instance.log_msg(nil, "#{thread_name} - Processor Configuration : #{@proc_config}", CommonUtils::LOG_DEBUG)
              end
              CommonUtils.instance.log_msg(nil, "#{thread_name} - Configuration Loaded Successfully", CommonUtils::LOG_INFO)
            else
              CommonUtils.instance.log_msg(nil, "No Config file provided", CommonUtils::LOG_ERROR)
            end
          end
        end
      end
    end
  end
end
