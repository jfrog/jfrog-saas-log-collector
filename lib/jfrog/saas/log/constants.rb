# frozen_string_literal: true

require_relative 'confighandler'

module Jfrog
  module Saas
    module Log
      class MessageUtils
        include Singleton
        SOLUTION = 'solution'
        LOG_LEVEL = 'log_level'

        CONNECTION_ERROR = 'Error occurred while connecting to %<param1>s , error is -> %<param2>s'
        ERROR_BACKTRACE = 'Error backtrace -> %<param1>s'

        CONFIG_LOAD_DETAIL = '%<param1>s - Configuration : %<param2>s'
        CONFIG_LOAD_BEGIN = '%<param1>s- Configuration Started, loading %<param2>s'
        CONFIG_LOAD_END = '%<param1>s- Configuration Loaded Successfully, loading %<param2>s'
        CONFIG_ERROR_NO_FILE = 'No Config file provided'

        SCHEDULER_NEXT_RUN = 'jfrog-saas-log-collector operation will run next at %<param1>s'
        APPLICATION_START = 'jfrog-saas-log-collector operation started'
        APPLICATION_STOP = 'jfrog-saas-log-collector operation ended'

        INIT_VERIFICATION = 'Resource %<param1>s and audit log repo %<param2>s found, proceeding with jfrog-saas-log-collector operation'
        FORCE_USE_CURRENT_DATE = 'Error occurred while parsing date : %<param1>s, setting current date'
        LOG_SHIPPING_ENABLED = 'Log shipping is -> %<param1>s on %<param2>s'
        LOG_SHIPPING_NOT_ENABLED = 'Log collection is not enabled for %<param1>s, please contact JFrog Support to enable log collection, terminating jfrog-saas-log-collector operation'
        LOG_SHIPPING_ENABLED_LOGS_NOT_COLLECTABLE = 'Log collection is enabled for %<param1>s, please wait for 24 hours if enabled recently for logs to be collected, terminating jfrog-saas-log-collector operation'
        LOG_SHIPPING_CHECK_CALL_FAIL_DETAIL = "Log shipping check error on %<param1>s, server response -> \n%<param2>s"
        AUDIT_REPO_NOT_FOUND_APPLICATION_STOP = 'Resource Audit log repo %<param1>s is not found, terminating jfrog-saas-log-collector operation'
        INIT_FAILED_APPLICATION_STOP = 'Resource %<param1>s not found <OR> audit log repo %<param2>s is not found, terminating jfrog-saas-log-collector operation'

        RESOURCE_CHECK_SUCCESS = 'Checking for Resource %<param1>s and it is found'
        RESOURCE_CHECK_FAILED_DETAIL = "Checking for Resource %<param1>s and it is not found, server response -> \n%<param2>s"

        FILE_DOWNLOAD_URL_AND_SIZE = 'Downloading log %<param1>s of size %<param2>s'
        AUDIT_FILE_CREATION_FAILED = 'Audit File creation for %<param1>s failed'
        AUDIT_FILE_CREATION_FAILED_DETAIL = "Error while creating audit for %<param1>s, server response -> \n%<param2>s"
        AUDIT_FILE_CREATION_SUCCESS = 'Audit File for %<param1>s successfully created'

        AUDIT_REPO_CREATION_FAILED_DETAIL = "Audit Logs Repo %<param1>s error in creation, server response -> \n%<param2>s"
        AUDIT_REPO_CREATION_SUCCESS = 'Audit Logs Repo %<param1>s successfully created'
        AUDIT_REPO_CHECK_CALL_DETAIL = "URL: %<param1>s, \n headers: %<param2>s, \n body: %<param3>s "

        AUDIT_REPO_TGT_DIR_CREATION_FAILED_DETAIL = "Audit Logs Target %<param1>s error in creation, server response -> \n%<param2>s"
        AUDIT_REPO_TGT_DIR_CREATION_SUCCESS = 'Audit Logs Target %<param1>s successfully created'
        AUDIT_REPO_TGT_DIR_CHECK_CALL_DETAIL = "URL: %<param1>s, \n headers: %<param2>s, \n body: %<param3>s "

        NO_LOGS_FOR_DATE = 'Resulting Logs for %<param1>s -> NONE'
        DOWNLOAD_FILE_AND_EXTRACT = 'Downloaded log %<param1>s and extracting it to %<param2>s'
        EXTRACT_LOG_FILE_SUCCESS = 'Extracted log %<param1>s  successfully written the content to %<param2>s'
        LOG_NOT_PROCESSED_INCLUDE = '%<param1>s is not processed, including'
        LOG_PROCESSED_EXCLUDE = '%<param1>s is already processed, skipping'
        DATE_VS_LOGS_DATA = 'Resulting Logs for %<param1>s -> %<param2>s'
        DATE_VS_PROCESSED_LOGS_DATA = 'Resulting Processed Logs for %<param1>s  -> %<param2>s'
        PROCESSED_LOGS_AQL_QUERY_RESULT = 'Fetching list of processed logs from AQL with params -> %<param1>s'
        UNPROCESSED_LOGS_AQL_QUERY_RESULT = 'Fetching list of logs from AQL with params -> %<param1>s'

        PURGE_RETAIN_DAYS_FOR_FILE = 'File %<param1>s has time of %<param2>s days to be retained'
        PURGE_SUCCESS_FOR_FILE = 'File %<param1>s purged successfully'

        CONFIG_FILE_VALIDATION_FAILED_DETAILS = 'Config File Validation failed, reason -> %<param1>s'
        CONFIG_FILE_PROVIDED_IS_NOT_VALID = "Config file provided %<param1>s is an \e[31mInvalid YAML file\e[0m, terminating jfrog-saas-log-collector operation "
        CONFIG_TEMPLATE_SUCCESSFULLY_WRITTEN = 'Config file from template written successfully to %<param1>s, modify necessary values before use'
        NO_CONFIG_FILE_PROVIDED = 'No config file provided, use -c option for config file path or provide the path in LOG_COLLECTOR_CONFIG environment variable, shutting down process %<param1>s, terminating jfrog-saas-log-collector operation'
        VALID_CONFIG_FILE_PROVIDED = "Config file provided %<param1>s is a \e[32mValid YAML\e[0m file, starting jfrog-saas-log-collector configuration"
        RECEIVED_AN_INVALID_OPTION_FLAG = "Received an\e[31m %<param1>s \e[0m, use -h or --help flag to list valid options, terminating jfrog-saas-log-collector operation "

        SHUT_DOWN_PROCESS = 'Shutting down process p_id #%<param1>s, terminating jfrog-saas-log-collector operation'
        TERMINATING_THREAD = 'Terminating thread t_id - #%<param1>s'

        SOLUTION_OVERRIDE_TERMINATE = 'terminate'
        SOLUTION_OVERRIDE_INIT = 'init'
        SOLUTION_OVERRIDE_START = 'start'
        SOLUTION_OVERRIDE_STOP = 'stop'
        SOLUTION_OVERRIDE_DEFAULT = 'default'
        SOLUTION_OVERRIDE_NEXT_RUN = 'next-run'

        # LOGGING RELATED SEGMENT - BEGIN

        def handle_log(solution, message, log_level)
          solution = MessageUtils::SOLUTION_OVERRIDE_DEFAULT if solution.nil? || solution.empty?
          log_line = if !LogConfig.instance.print_with_utc
                       "| #{solution.upcase} | #{message}"
                     else
                       "| #{Time.now.getutc.strftime('%Y-%m-%d %H:%M:%S.%3N ')}#{Time.now.getutc.zone} | #{solution.upcase} | #{message}"
                     end

          case log_level
          when CommonUtils::LOG_ERROR
            LogConfig.instance.console_logger.error(log_line)
            LogConfig.instance.logger.error(log_line)
          when CommonUtils::LOG_WARN
            LogConfig.instance.console_logger.warn(log_line)
            LogConfig.instance.logger.warn(log_line)
          when CommonUtils::LOG_DEBUG
            LogConfig.instance.console_logger.debug(log_line)
            LogConfig.instance.logger.debug(log_line)
          else
            LogConfig.instance.console_logger.info(log_line)
            LogConfig.instance.logger.info(log_line)
          end
        end

        def handle_put(solution, message, log_level)
          formatted_date = Time.now.strftime('%Y-%m-%d %H:%M:%S')
          solution = MessageUtils::SOLUTION_OVERRIDE_DEFAULT if solution.nil? || solution.empty?
          case log_level
          when CommonUtils::LOG_ERROR || CommonUtils::LOG_WARN
            warn "[ #{formatted_date}, p_id=##{Process.pid}, t_id=##{Thread.current.object_id}, #{CommonUtils::LOG_ERROR.upcase} ] -- | #{Time.now.getutc.strftime('%Y-%m-%d %H:%M:%S.%3N ')}#{Time.now.getutc.zone} | #{solution.upcase} | #{message}"
          else CommonUtils::LOG_DEBUG || CommonUtils::LOG_INFO
               puts "[ #{formatted_date}, p_id=##{Process.pid}, t_id=##{Thread.current.object_id}, #{CommonUtils::LOG_INFO.upcase} ] -- | #{Time.now.getutc.strftime('%Y-%m-%d %H:%M:%S.%3N ')}#{Time.now.getutc.zone} | #{solution.upcase} | #{message}"
          end
        end

        # LOGGING RELATED SEGMENT - END
        def log_message(message, substitutions)
          temp_message = message.dup
          temp_message = temp_message % substitutions
          handle_log(substitutions[MessageUtils::SOLUTION.to_sym], temp_message, substitutions[MessageUtils::LOG_LEVEL.to_sym])
        end

        # LOGGING RELATED SEGMENT - END
        def put_message(message, substitutions)
          temp_message = message.dup
          temp_message = temp_message % substitutions
          handle_put(substitutions[MessageUtils::SOLUTION.to_sym], temp_message, substitutions[MessageUtils::LOG_LEVEL.to_sym])
        end
      end
    end
  end
end

