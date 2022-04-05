# frozen_string_literal: true

require 'json'
require 'date'
require 'zlib'
require 'stringio'
require 'logger'

require_relative 'constants'
require_relative 'confighandler'
require_relative 'unzipper'
require_relative 'connectionmanager'

module Jfrog
  module Saas
    module Log
      class CommonUtils
        include Singleton
        DELIM = '_@@_'
        HTTP_GET = 'get'
        HTTP_PUT = 'put'
        HTTP_PATCH = 'patch'
        HTTP_DELETE = 'delete'
        HTTP_POST = 'post'
        CONTENT_TYPE_JSON = 'application/json'
        CONTENT_TYPE_TEXT = 'text/plain'
        CONTENT_TYPE_HDR = 'Content-Type'
        FILE_PROCESSING_LOCK = 'LOCK'
        FILE_PROCESSING_SUCCESS = 'SUCCESS'
        STATUS_FILE_SUFFIX = '.status.json'
        LOCK_FILE_SUFFIX = '.lock'
        LOG_ERROR = 'error'
        LOG_WARN = 'warn'
        LOG_INFO = 'info'
        LOG_DEBUG = 'debug'

        # STRING MANIPULATIONS AND OTHER SIMPLE UTILS - BEGIN
        def get_log_url_for_date(solution, date_in_string)
          log_repo_url + "/#{solution}/#{date_in_string}"
        end

        def audit_repo_url
          ConfigHandler.instance.log_config.audit_repo_url.to_s
        end

        def log_repo_url
          ConfigHandler.instance.log_config.log_repo_url.to_s
        end

        def artifactory_log_url(date)
          "/#{ConfigHandler.instance.conn_config.end_point_base}/#{date}"
        end

        def log_ship_config_url
          "/#{ConfigHandler.instance.log_config.log_ship_config}"
        end

        def artifactory_aql_url
          "/#{ConfigHandler.instance.conn_config.end_point_base}/api/search/aql"
        end

        def artifactory_aql_body(solution, date_in_string)
          "items.find({\"repo\": \"#{((log_repo_url).split("/"))[1]}\", \"path\" : {\"$match\":\"#{solution}/#{date_in_string}\"}, \"name\" : {\"$match\":\"*log.gz\"}})"
        end

        def audit_aql_body(solution, date_in_string)
          "items.find({\"repo\": \"#{((audit_repo_url).split("/"))[1]}\", \"path\" : {\"$match\":\"#{solution}/#{date_in_string}\"}, \"name\" : {\"$match\":\"*log.gz#{CommonUtils::STATUS_FILE_SUFFIX}\"}})"
        end

        def audit_aql_locked_files_body(solution, date_in_string)
          "items.find({\"repo\": \"#{((audit_repo_url).split("/"))[1]}\", \"path\" : {\"$match\":\"#{solution}/#{date_in_string}\"}, \"name\" : {\"$match\":\"*log.gz#{CommonUtils::LOCK_FILE_SUFFIX}\"}})"
        end

        def audit_specific_file_lock(solution, download_file_name)
          "items.find({\"repo\": \"#{((audit_repo_url).split("/"))[1]}\", \"path\" : {\"$match\":\"#{solution}/*\"}, \"name\" : {\"$match\":\"#{download_file_name}#{CommonUtils::LOCK_FILE_SUFFIX}\"}})"
        end

        def audit_repo_create_url
          "#{ConfigHandler.instance.conn_config.end_point_base}/api/repositories/#{((audit_repo_url).split("/"))[1]}"
        end

        def audit_repo_create_body
          "{
            \"key\": \"#{((audit_repo_url).split("/"))[1]}\",
            \"environments\":[\"PROD\"],
            \"rclass\" : \"local\",
            \"packageType\": \"generic\",
            \"repoLayoutRef\": \"simple-default\",
            \"description\": \"This repository is for auditing the jfrog-saas-log-collector downloads and extracts\"
          }"
        end

        def audit_repo_target_dir_url(target_dir_string, repo_only_req, full_uri_req, trailing_uri_req)
          uri = ''

          if repo_only_req
            uri = (((audit_repo_url).split('/'))[1]).to_s
          elsif full_uri_req
            uri = "#{ConfigHandler.instance.conn_config.jpd_url}/#{ConfigHandler.instance.conn_config.end_point_base}/#{((audit_repo_url).split("/"))[1]}/#{target_dir_string}"
          elsif !full_uri_req
            uri = "#{ConfigHandler.instance.conn_config.end_point_base}/#{((audit_repo_url).split("/"))[1]}/#{target_dir_string}"
          end

          if trailing_uri_req
            uri = "#{uri}/" # this trailing '/' is very important for directory creations, else Artifactory APIs think they are files
          end

          uri
        end

        def audit_repo_create_tgt_dir_body(target_dir_string)
          "{
            \"uri\": \"#{audit_repo_target_dir_url(target_dir_string, false, true, false)}\",
            \"repo\": \"#{audit_repo_target_dir_url(target_dir_string, true, false, false)}\",
            \"path\" : \"#{audit_repo_target_dir_url(target_dir_string, false, false, false)}\",
            \"created\": \"#{DateTime.now.iso8601}\",
            \"createdBy\": \"#{ConfigHandler.instance.conn_config.username}\",
            \"children\": [ ]
          }"
        end

        def audit_file_status_body(file_name, file_extract_status)
          "{
            \"file_name\": \"#{file_name.chomp(CommonUtils::STATUS_FILE_SUFFIX)}\",
            \"download_extract_status\": \"#{file_extract_status}\",
            \"event_time\": \"#{DateTime.now.iso8601}\",
            \"createdBy\": \"jfrog-saas-log-collector\"
          }"
        end

        def get_size_in_mb(bytes, return_string)
          if return_string
            "#{(bytes / (1024.0 * 1024.0)).round(2)} MB"
          else
            (bytes / (1024.0 * 1024.0)).round(2)
          end
        end

        def generate_dates_list(solution, start_date_str, end_date_str)
          dates_list = []
          diff_days = 0
          start_date = parse_date(solution, start_date_str)
          end_date = parse_date(solution, end_date_str)
          diff_days = end_date.mjd - start_date.mjd if end_date >= start_date
          if !diff_days.nil? && diff_days.positive?
            diff_days.times do |index|
              dates_list.push(start_date + index)
            end
          else
            dates_list.push(end_date)
          end

          dates_list
        end

        def parse_date(solution, date_in_str)
          date_pattern = if ConfigHandler.instance.log_config.uri_date_pattern.nil?
                           '%Y-%m-%d'
                         else
                           ConfigHandler.instance.log_config.uri_date_pattern
                         end
          Date.strptime(date_in_str, date_pattern)
        rescue ArgumentError => e
          MessageUtils.instance.log_message(MessageUtils::FORCE_USE_CURRENT_DATE, { "param1": e.message.to_s,
                                                                                    "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                    "#{MessageUtils::SOLUTION}": solution } )
          Date.today
        end

        def logs_to_process_between(solution, start_date_str, end_date_str)
          generate_dates_list(solution, start_date_str, end_date_str)
        end
        # STRING MANIPULATIONS AND OTHER SIMPLE UTILS - END

        # RESOURCE RELATED - BEGIN
        def check_if_resource_exists(solution, relative_url)
          resource_exists = false
          conn_mgr = ConnectionManager.new
          headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_JSON }
          response = conn_mgr.execute(relative_url, nil, headers, nil, CommonUtils::HTTP_GET, true)
          if !response.nil? && response.status >= 200 && response.status < 300
            resource_exists = true
            MessageUtils.instance.log_message(MessageUtils::RESOURCE_CHECK_SUCCESS, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{relative_url}",
                                                                                      "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                      "#{MessageUtils::SOLUTION}": solution } )
          else
            MessageUtils.instance.log_message(MessageUtils::RESOURCE_CHECK_FAILED_DETAIL, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{relative_url}",
                                                                                            "param2": response.body.to_s,
                                                                                            "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                            "#{MessageUtils::SOLUTION}": solution } )
          end
          resource_exists
        end

        def log_shipping_enabled
          log_shipping = false
          conn_mgr = ConnectionManager.new
          headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_JSON }
          response = conn_mgr.execute(log_ship_config_url, nil, headers, nil, CommonUtils::HTTP_GET, true)
          if !response.nil? && response.status >= 200 && response.status < 300
            log_shipping = response.body['enabled']
            MessageUtils.instance.log_message(MessageUtils::LOG_SHIPPING_ENABLED, { "param1": log_shipping.to_s,
                                                                                    "param2": "#{ConfigHandler.instance.conn_config.jpd_url}/#{log_ship_config_url}",
                                                                                    "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                    "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT } )
          else
            MessageUtils.instance.log_message(MessageUtils::LOG_SHIPPING_CHECK_CALL_FAIL_DETAIL, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{log_ship_config_url}",
                                                                                                   "param2": response.body.to_s,
                                                                                                   "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                   "#{MessageUtils::SOLUTION}": MessageUtils::SOLUTION_OVERRIDE_INIT } )
          end
          log_shipping
        end

        def check_and_create_audit_repo
          audit_log_repo_exists = check_if_resource_exists(nil, audit_repo_create_url)
          unless audit_log_repo_exists
            conn_mgr = ConnectionManager.new
            headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_JSON }
            body = audit_repo_create_body
            if ConfigHandler.instance.log_config.debug_mode
              MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_CHECK_CALL_DETAIL, { "param1": audit_repo_create_url.to_s,
                                                                                              "param2": headers.to_s,
                                                                                              "param3": audit_repo_create_body.to_s,
                                                                                              "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG,
                                                                                              "#{MessageUtils::SOLUTION}": nil })
            end
            response = conn_mgr.execute(audit_repo_create_url, nil, headers, body, CommonUtils::HTTP_PUT, true)
            if !response.nil? && (response.status >= 200 && response.status < 300)
              MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_CREATION_SUCCESS, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url}",
                                                                                             "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                             "#{MessageUtils::SOLUTION}": nil })
              audit_log_repo_exists = true
            else
              MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_CREATION_FAILED_DETAIL, { "param1": "#{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url}",
                                                                                                   "param2": response.body.to_s,
                                                                                                   "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                   "#{MessageUtils::SOLUTION}": nil })
              audit_log_repo_exists = false
            end
          end
          audit_log_repo_exists
        end


        def check_create_tgt_dir(solution, tgt_dir_str)
          audit_log_repo_tgt_dir_exists = check_if_resource_exists(solution, audit_repo_target_dir_url(tgt_dir_str, false, false, false))
          unless audit_log_repo_tgt_dir_exists
            conn_mgr = ConnectionManager.new
            headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_JSON }
            body = audit_repo_create_tgt_dir_body(tgt_dir_str)
            if ConfigHandler.instance.log_config.debug_mode
              MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_TGT_DIR_CHECK_CALL_DETAIL, { "param1": "#{audit_repo_target_dir_url(tgt_dir_str, false, true, true)}",
                                                                                                      "param2": headers.to_s,
                                                                                                      "param3": audit_repo_create_tgt_dir_body(tgt_dir_str).to_s,
                                                                                                      "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG,
                                                                                                      "#{MessageUtils::SOLUTION}": solution })
            end
            response = conn_mgr.execute(audit_repo_target_dir_url(tgt_dir_str, false, false, true), nil, headers, body, CommonUtils::HTTP_PUT, true)
            if !response.nil? && (response.status >= 200 && response.status < 300)
              MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_TGT_DIR_CREATION_SUCCESS, { "param1": "#{audit_repo_target_dir_url(tgt_dir_str, false, true, false)}",
                                                                                                     "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                                     "#{MessageUtils::SOLUTION}": nil })
              audit_log_repo_tgt_dir_exists = true
            else
              MessageUtils.instance.log_message(MessageUtils::AUDIT_REPO_TGT_DIR_CREATION_FAILED_DETAIL, { "param1": "#{audit_repo_target_dir_url(tgt_dir_str, false, true, false)}",
                                                                                                           "param2": response.body.to_s,
                                                                                                           "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                           "#{MessageUtils::SOLUTION}": solution })
            end
          end
          audit_log_repo_tgt_dir_exists
        end

        def audit_lock_file(solution, audit_file)
          audit_lock_file_found = false
          conn_mgr = ConnectionManager.new
          body = audit_specific_file_lock(solution, audit_file)
          headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_TEXT }
          if ConfigHandler.instance.log_config.debug_mode
            MessageUtils.instance.log_message(MessageUtils::AUDIT_LOCK_AQL_QUERY_RESULT, { "param1": body.to_s,
                                                                                           "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG,
                                                                                           "#{MessageUtils::SOLUTION}": solution })
          end
          response = conn_mgr.execute(artifactory_aql_url, nil, headers, body, CommonUtils::HTTP_POST, false)
          if !response.nil? && (response.status >= 200 && response.status < 300) && response.headers[CommonUtils::CONTENT_TYPE_HDR] == CommonUtils::CONTENT_TYPE_JSON
            parsed_json = JSON.parse(response.body)
            total_records = parsed_json['range']['total']
            if total_records.positive?
              results = parsed_json['results']
              message = if ConfigHandler.instance.log_config.debug_mode
                          JSON.pretty_generate(results)
                        else
                          total_records
                        end
              MessageUtils.instance.log_message(MessageUtils::SOLUTION_VS_LOCKED_FILE_DATA, { "param1": solution.to_s,
                                                                                             "param2": message,
                                                                                             "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                             "#{MessageUtils::SOLUTION}": solution })
              audit_lock_file_found = true
            end
          end
          audit_lock_file_found
        end

        def handle_audit_file(solution, tgt_date_str, file_name, status, method)
          status_audit_success = false
          conn_mgr = ConnectionManager.new
          headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_JSON }
          body = audit_file_status_body(file_name, status) if CommonUtils::HTTP_PUT == method
          response = conn_mgr.execute("#{audit_repo_target_dir_url("#{solution}/#{tgt_date_str}", false, false, false)}/#{file_name}", nil, headers, body, method, true)
          if !response.nil? && (response.status >= 200 && response.status < 300)
            if CommonUtils::HTTP_PUT == method
            MessageUtils.instance.log_message(MessageUtils::AUDIT_FILE_CREATION_SUCCESS, { "param1": "#{audit_repo_target_dir_url("#{solution}/#{tgt_date_str}", false, true, false)}/#{file_name}",
                                                                                                 "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                                 "#{MessageUtils::SOLUTION}": solution })
            elsif CommonUtils::HTTP_DELETE == method
              MessageUtils.instance.log_message(MessageUtils::AUDIT_FILE_DELETE_SUCCESS, { "param1": "#{audit_repo_target_dir_url("#{solution}/#{tgt_date_str}", false, true, false)}/#{file_name}",
                                                                                             "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                             "#{MessageUtils::SOLUTION}": solution })
            end
            status_audit_success = true
          else
            if CommonUtils::HTTP_PUT == method
            MessageUtils.instance.log_message(MessageUtils::AUDIT_FILE_CREATION_FAILED_DETAIL, { "param1": "#{audit_repo_target_dir_url("#{solution}/#{tgt_date_str}", false, true, false)}/#{file_name}",
                                                                                                 "param2": response.body.to_s,
                                                                                                 "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                 "#{MessageUtils::SOLUTION}": solution })
            elsif CommonUtils::HTTP_DELETE == method
              MessageUtils.instance.log_message(MessageUtils::AUDIT_FILE_DELETE_FAILED_DETAIL, { "param1": "#{audit_repo_target_dir_url("#{solution}/#{tgt_date_str}", false, true, false)}/#{file_name}",
                                                                                                   "param2": response.body.to_s,
                                                                                                   "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_ERROR,
                                                                                                   "#{MessageUtils::SOLUTION}": solution })
            end

          end
          status_audit_success
        end

        def clear_audit_locks(solution, date_in_string)
          locks_cleared = []
          conn_mgr = ConnectionManager.new
          headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_TEXT }
          body =  audit_aql_locked_files_body(solution, date_in_string)
          response = conn_mgr.execute(artifactory_aql_url, nil, headers, body, CommonUtils::HTTP_POST, false)
          if !response.nil? && (response.status >= 200 && response.status < 300) && response.headers[CommonUtils::CONTENT_TYPE_HDR] == CommonUtils::CONTENT_TYPE_JSON
            parsed_json = JSON.parse(response.body)
            total_records = parsed_json['range']['total']
            if total_records.positive?
              results = parsed_json['results']
              results.each do |log_file_detail|
                created_time = DateTime.parse(log_file_detail['created'])
                diff_minutes = ((DateTime.now - created_time) * 24 * 60).to_i
                if diff_minutes >= ConfigHandler.instance.proc_config.minutes_between_runs
                  handle_audit_file(solution, date_in_string, "#{log_file_detail['name']}", CommonUtils::FILE_PROCESSING_LOCK, CommonUtils::HTTP_DELETE)
                  locks_cleared.push(log_file_detail['name'])
                end
              end
            end
          end
          MessageUtils.instance.log_message(MessageUtils::LOCKED_AUDIT_FILES_CLEARED_RESULT, { "param1": locks_cleared.to_s,
                                                                                             "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG,
                                                                                             "#{MessageUtils::SOLUTION}": solution })
          locks_cleared
        end

        def logs_processed(solution, date_in_string)
          logs_processed = []
          conn_mgr = ConnectionManager.new
          headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_TEXT }
          body = audit_aql_body(solution, date_in_string)
          if ConfigHandler.instance.log_config.debug_mode
            MessageUtils.instance.log_message(MessageUtils::PROCESSED_LOGS_AQL_QUERY_RESULT, { "param1": body.to_s,
                                                                                               "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG,
                                                                                               "#{MessageUtils::SOLUTION}": solution })
          end
          response = conn_mgr.execute(artifactory_aql_url, nil, headers, body, CommonUtils::HTTP_POST, false)
          if !response.nil? && (response.status >= 200 && response.status < 300) && response.headers[CommonUtils::CONTENT_TYPE_HDR] == CommonUtils::CONTENT_TYPE_JSON
            parsed_json = JSON.parse(response.body)
            total_records = parsed_json['range']['total']
            if total_records.positive?
              results = parsed_json['results']
              message = if ConfigHandler.instance.log_config.debug_mode
                          JSON.pretty_generate(results)
                        else
                          total_records
                        end
              MessageUtils.instance.log_message(MessageUtils::DATE_VS_PROCESSED_LOGS_DATA, { "param1": date_in_string.to_s,
                                                                                             "param2": message,
                                                                                             "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                             "#{MessageUtils::SOLUTION}": solution })
              results.each do |log_file_detail|
                logs_processed.push(log_file_detail['name'].chomp(CommonUtils::STATUS_FILE_SUFFIX))
              end
            end
          end
          logs_processed
        end

        def logs_to_process_hash(solution, date_in_string)
          logs_processed = logs_processed(solution, date_in_string)
          logs_to_process = {}
          conn_mgr = ConnectionManager.new
          body = artifactory_aql_body(solution, date_in_string)
          headers = { CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_TEXT }
          if ConfigHandler.instance.log_config.debug_mode
            MessageUtils.instance.log_message(MessageUtils::UNPROCESSED_LOGS_AQL_QUERY_RESULT, { "param1": body.to_s,
                                                                                                 "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_DEBUG,
                                                                                                 "#{MessageUtils::SOLUTION}": solution })
          end
          response = conn_mgr.execute(artifactory_aql_url, nil, headers, body, CommonUtils::HTTP_POST, false)
          if !response.nil? && (response.status >= 200 && response.status < 300) && response.headers[CommonUtils::CONTENT_TYPE_HDR] == CommonUtils::CONTENT_TYPE_JSON
            parsed_json = JSON.parse(response.body)
            total_records = parsed_json['range']['total']
            if total_records.positive?
              results = parsed_json['results']
              message = if ConfigHandler.instance.log_config.debug_mode
                          JSON.pretty_generate(results)
                        else
                          total_records
                        end
              MessageUtils.instance.log_message(MessageUtils::DATE_VS_LOGS_DATA, { "param1": date_in_string.to_s,
                                                                                   "param2": message,
                                                                                   "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                   "#{MessageUtils::SOLUTION}": solution })
              results.each do |log_file_detail|
                if logs_processed.include? log_file_detail['name']
                  MessageUtils.instance.log_message(MessageUtils::LOG_PROCESSED_EXCLUDE, { "param1": log_file_detail['name'].to_s,
                                                                                           "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                           "#{MessageUtils::SOLUTION}": solution })
                elsif ConfigHandler.instance.log_config.log_types_enabled.any? { |log_type| log_file_detail['name'].include? log_type }
                  MessageUtils.instance.log_message(MessageUtils::LOG_NOT_PROCESSED_INCLUDE, { "param1": log_file_detail['name'].to_s,
                                                                                               "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                               "#{MessageUtils::SOLUTION}": solution })
                  logs_to_process[log_file_detail['name']] = log_file_detail
                end
              end
            else
              MessageUtils.instance.log_message(MessageUtils::NO_LOGS_FOR_DATE, { "param1": date_in_string.to_s,
                                                                                  "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                  "#{MessageUtils::SOLUTION}": solution })
            end
          end
          logs_to_process
        end
        # RESOURCE RELATED - END

        def download_and_extract_log(solution, date, target_path, file_name, relative_url)
          conn_mgr = ConnectionManager.new
          headers = {
            CommonUtils::CONTENT_TYPE_HDR => CommonUtils::CONTENT_TYPE_TEXT,
            'Accept-Encoding' => 'gzip, deflate',
            'Accept' => 'text/plain,text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9'
          }

          if !audit_lock_file(solution, file_name)
            handle_audit_file(solution, date, "#{file_name}#{CommonUtils::LOCK_FILE_SUFFIX}", CommonUtils::FILE_PROCESSING_LOCK, CommonUtils::HTTP_PUT)
            response = conn_mgr.execute(relative_url, nil, headers, nil, CommonUtils::HTTP_GET, true)
            if !response.nil? && response.status >= 200 && response.status < 300
              log_file_name = file_name.chomp('.gz')
              if ConfigHandler.instance.proc_config.write_logs_by_type
                ConfigHandler.instance.log_config.log_types_enabled.each do |log_type|
                  log_file_name = "#{log_type}.log" if log_file_name.include? log_type
                end
              end
              MessageUtils.instance.log_message(MessageUtils::DOWNLOAD_FILE_AND_EXTRACT, { "param1": relative_url.to_s,
                                                                                           "param2": "#{target_path}/#{solution}/#{log_file_name}",
                                                                                           "#{MessageUtils::LOG_LEVEL}": CommonUtils::LOG_INFO,
                                                                                           "#{MessageUtils::SOLUTION}": solution })
              unzip = Unzip.new
              unzip.extract(solution, relative_url, target_path, log_file_name, response.body)
              handle_audit_file(solution, date, "#{file_name}#{CommonUtils::LOCK_FILE_SUFFIX}", CommonUtils::FILE_PROCESSING_LOCK, CommonUtils::HTTP_DELETE)
              handle_audit_file(solution, date, "#{file_name}#{CommonUtils::STATUS_FILE_SUFFIX}", CommonUtils::FILE_PROCESSING_SUCCESS, CommonUtils::HTTP_PUT)
            end
          end
        end
      end
    end
  end
end

