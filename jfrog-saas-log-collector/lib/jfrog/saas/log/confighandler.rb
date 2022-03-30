# frozen_string_literal: true

require "optparse"
require "yaml"
require "singleton"
require 'fileutils'

require_relative "commonutils"
require_relative "constants"

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
        log_file_retention_days = 7

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

        def self.log_file_retention_days
          log_file_retention_days
        end

        attr_accessor :solutions_enabled, :log_types_enabled, :uri_date_pattern, :audit_repo_url, :log_repo_url, :debug_mode, :target_log_path, :log_ship_config, :logger, :console_logger, :print_with_utc, :log_file_retention_days

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          self.target_log_path = (config["log"]["target_log_path"]).to_s.strip
          log_file = "#{target_log_path}/jfrog-saas-collector.log"
          FileUtils.mkdir_p(target_log_path) unless File.directory? target_log_path
          FileUtils.touch(log_file) unless File.exist? log_file
          self.logger = Logger.new(log_file, "weekly")
          self.console_logger = Logger.new($stdout)

          console_logger.formatter = logger.formatter = proc do |severity, datetime, progname, msg|
            formatted_date = datetime.strftime("%Y-%m-%d %H:%M:%S")
            "[ #{formatted_date}, p_id=##{Process.pid}, t_id=##{Thread.current.object_id}, #{severity.ljust(5)}] -- #{msg} \n"
          end

          self.log_ship_config = (config["log"]["log_ship_config"])
          self.solutions_enabled = config["log"]["solutions_enabled"].split(",").map(&:strip)
          self.log_types_enabled = config["log"]["log_types_enabled"].split(",").map(&:strip)
          self.uri_date_pattern = (config["log"]["uri_date_pattern"]).to_s
          self.audit_repo_url = (config["log"]["audit_repo"]).to_s.strip
          self.log_repo_url = (config["log"]["log_repo"]).to_s.strip
          self.debug_mode = (config["log"]["debug_mode"])
          self.print_with_utc = (config["log"]["print_with_utc"])
          if (config["log"]["log_file_retention_days"]).to_i.positive?
            self.log_file_retention_days = (config["log"]["log_file_retention_days"]).to_i
          end

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

          if config["connection"]["open_timeout_in_secs"].to_i.positive?
            self.open_timeout_in_secs = config["connection"]["open_timeout_in_secs"].to_i
          end

          if config["connection"]["read_timeout_in_secs"].to_i.positive?
            self.read_timeout_in_secs = config["connection"]["read_timeout_in_secs"].to_i
          end

        end

        def to_s
          "Object_id :#{object_id}, jpd_url :#{jpd_url}, username:#{username}, access_token: #{access_token}, end_point_base:#{end_point_base}, api_key:#{api_key}"
        end
      end

      class ProcessConfig
        include Singleton
        parallel_process = 1
        parallel_downloads = 1
        historical_log_days = 1
        write_logs_by_type = false
        minutes_between_runs = 180

        def self.parallel_process
          parallel_process
        end

        def self.parallel_downloads
          parallel_downloads
        end

        def self.historical_log_days
          historical_log_days
        end

        def self.write_logs_by_type
          write_logs_by_type
        end

        def self.minutes_between_runs
          minutes_between_runs
        end

        attr_accessor :parallel_process, :parallel_downloads, :historical_log_days, :write_logs_by_type, :minutes_between_runs

        def initialize; end

        def configure(config_file, suffix)
          config = YAML.load_file(config_file)
          if config["process"]["parallel_process"].to_i.positive?
            self.parallel_downloads = config["process"]["parallel_process"].to_i
          end

          if config["process"]["parallel_downloads"].to_i.positive?
            self.parallel_downloads = config["process"]["parallel_downloads"].to_i
          end

          if config["process"]["historical_log_days"].to_i.positive?
            self.historical_log_days = config["process"]["historical_log_days"].to_i
          end

          self.write_logs_by_type = config["process"]["write_logs_by_type"]

          if config["process"]["minutes_between_runs"].to_i.positive?
            self.minutes_between_runs = config["process"]["minutes_between_runs"].to_i
          end
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

        @@file_name = ""

        def self.file_name(fn)
          @@file_name = fn
        end

        class << self
          attr_reader :conn_config
        end

        class << self
          attr_reader :log_config
        end

        class << self
          attr_reader :proc_config
        end

        attr_accessor :conn_config, :log_config, :proc_config, :file_name

        def initialize()
          @mutex = Mutex.new
          # If not found in options, check for the environment variable
          @config_path = if !@@file_name.nil?
                           @@file_name
                         else
                           ENV["LOG_COLLECTOR_CONFIG"]
                         end
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

              MessageUtils.instance.log_message(MessageUtils::CONFIG_LOAD_BEGIN, { "param1": thread_name, "param2": config_file, "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO } )
              if LogConfig.instance.debug_mode == true
                MessageUtils.instance.log_message(MessageUtils::CONFIG_LOAD_DETAIL, { "param1": thread_name, "param2": "#{@conn_config}", "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG} )
              end
              if LogConfig.instance.debug_mode == true
                MessageUtils.instance.log_message(MessageUtils::CONFIG_LOAD_DETAIL, { "param1": thread_name, "param2": "#{@log_config}", "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG} )
              end
              if LogConfig.instance.debug_mode == true
                MessageUtils.instance.log_message(MessageUtils::CONFIG_LOAD_DETAIL, { "param1": thread_name, "param2": "#{@proc_config}", "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG} )
              end
              MessageUtils.instance.log_message(MessageUtils::CONFIG_LOAD_END, { "param1": thread_name, "param2": config_file, "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO } )
            else
              MessageUtils.instance.log_message(MessageUtils::CONFIG_ERROR_NO_FILE, { "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR } )
            end
          end
        end
      end
    end
  end
end
