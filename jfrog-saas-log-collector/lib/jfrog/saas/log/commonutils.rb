# frozen_string_literal: true

require "json"
require "date"
require "zlib"
require "stringio"

require_relative "confighandler"
require_relative "unzipper"
require_relative "connectionmanager"

module Jfrog
  module Saas
    module Log
      class CommonUtils
        include Singleton
        DELIM = "_@@_"
        HTTP_GET = "get"
        HTTP_PUT = "put"
        HTTP_PATCH = "patch"
        HTTP_DELETE = "delete"
        HTTP_POST = "post"
        CONTENT_TYPE_JSON = "application/json"
        CONTENT_TYPE_TEXT = "text/plain"
        CONTENT_TYPE_HDR = "Content-Type"

        def print_msg(solution, message)
          print_msg_with_pp(solution, message, false)
        end

        def pretty_print_msg(solution, message)
          print_msg_with_pp(solution, message, true)
        end

        def print_msg_with_pp(solution, message, pretty_print)
          solution = "default" if solution.nil? || solution.empty?
          if !pretty_print
            puts "#{Time.now.getutc.strftime("%Y-%m-%d %H:%M:%S.%3N ")}#{Time.now.getutc.zone} | #{solution} | #{message}"
          else
            puts "#{Time.now.getutc.strftime("%Y-%m-%d %H:%M:%S.%3N ")}#{Time.now.getutc.zone} | #{solution} | Formatted Message"
            pp message.to_s
            puts "\n"
          end
        end

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
          "items.find({\"repo\": \"jfrog-logs\", \"path\" : {\"$match\":\"#{solution}/#{date_in_string}\"}, \"name\" : {\"$match\":\"*log.gz\"}})"
        end

        def audit_repo_create_url
          "/#{ConfigHandler.instance.conn_config.end_point_base}/api/repositories/#{((audit_repo_url).split("/"))[1]}"
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

        def get_size_in_mb(bytes, return_string)
          if return_string
            "#{(bytes / (1024.0 * 1024.0)).round(2)} MB"
          else
            (bytes / (1024.0 * 1024.0)).round(2)
          end
        end

        def log_shipping_enabled
          log_shipping = false
          CommonUtils.instance.print_msg(nil, "Checking for Log shipping enablement #{ConfigHandler.instance.conn_config.jpd_url}/#{log_ship_config_url}")
          conn_mgr = ConnectionManager.new
          headers = { "Content-Type" => CommonUtils::CONTENT_TYPE_JSON }
          response = conn_mgr.execute(log_ship_config_url, nil, headers, nil, CommonUtils::HTTP_GET, true)
          if !response.nil? && response.status >= 200 && response.status < 300
            log_shipping = response.body["enabled"]
            CommonUtils.instance.print_msg(nil, "Log shipping is -> #{log_shipping}")
          else
            CommonUtils.instance.print_msg(nil, "Error while accessing #{ConfigHandler.instance.conn_config.jpd_url}/#{log_ship_config_url}, server response -> \n#{response.body}")
          end
          log_shipping
        end

        def check_if_resource_exists(relative_url)
          resource_exists = false
          CommonUtils.instance.print_msg(nil, "Checking for Resource #{ConfigHandler.instance.conn_config.jpd_url}/#{relative_url}")
          conn_mgr = ConnectionManager.new
          headers = { "Content-Type" => CommonUtils::CONTENT_TYPE_TEXT }
          response = conn_mgr.execute(relative_url, nil, headers, nil, CommonUtils::HTTP_GET, true)
          if !response.nil? && response.status >= 200 && response.status < 300
            resource_exists = true
            CommonUtils.instance.print_msg(nil, "Resource #{ConfigHandler.instance.conn_config.jpd_url}/#{relative_url} found")
          else
            CommonUtils.instance.print_msg(nil, "Error while accessing #{ConfigHandler.instance.conn_config.jpd_url}/#{relative_url}, server response -> \n#{response.body}")
          end
          resource_exists
        end

        def generate_dates_list(solution, start_date_str, end_date_str)
          dates_list = []
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
                           "%Y-%m-%d"
                         else
                           ConfigHandler.instance.log_config.uri_date_pattern
                         end
          Date.strptime(date_in_str, date_pattern)
        rescue ArgumentError => e
          CommonUtils.instance.print_msg(solution, "Error occurred while parsing date : #{e.message}, setting current date")
          Date.today
        end

        def logs_to_process_between(solution, start_date_str, end_date_str)
          generate_dates_list(solution, start_date_str, end_date_str)
        end

        def check_and_create_audit_repo
          audit_log_repo_exists = false
          if check_if_resource_exists(CommonUtils.instance.audit_repo_url)
            CommonUtils.instance.print_msg(nil, "Audit Logs Repo #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} found")
            audit_log_repo_exists = true
          else
            conn_mgr = ConnectionManager.new
            headers = { "Content-Type" => CommonUtils::CONTENT_TYPE_JSON }
            CommonUtils.instance.print_msg(nil, "URL: #{audit_repo_create_url}, \n headers: #{headers}, \n body: #{audit_repo_create_body} ") if ConfigHandler.instance.log_config.debug_mode
            response = conn_mgr.execute(audit_repo_create_url, nil, headers, audit_repo_create_body, CommonUtils::HTTP_PUT, true)
            if !response.nil? && (response.status >= 200 && response.status < 300)
              CommonUtils.instance.print_msg(nil, "Audit Logs Repo #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} successfully created")
              audit_log_repo_exists = true
            else
              CommonUtils.instance.print_msg(nil, "Audit Logs Repo #{ConfigHandler.instance.conn_config.jpd_url}/#{CommonUtils.instance.audit_repo_url} error in creation, server response -> \n#{response.body}")
              audit_log_repo_exists = false
            end
          end
          audit_log_repo_exists
        end

        # 3. Download each log and update the audit repo with download details
        # 4. Once all the downloads are complete use the same list to perform extraction or deflate it post download to the target location

        def logs_to_process_hash(solution, date_in_string)
          logs_to_process = {}
          conn_mgr = ConnectionManager.new
          body = artifactory_aql_body(solution, date_in_string)
          headers = { "Content-Type" => CommonUtils::CONTENT_TYPE_TEXT }
          CommonUtils.instance.print_msg(solution, "Fetching list of logs from AQL with params -> #{body}")
          response = conn_mgr.execute(artifactory_aql_url, nil, headers, body, CommonUtils::HTTP_POST, false)
          if !response.nil? && (response.status >= 200 && response.status < 300) && response.headers[CommonUtils::CONTENT_TYPE_HDR] == CommonUtils::CONTENT_TYPE_JSON
            parsed_json = JSON.parse(response.body)
            total_records = parsed_json["range"]["total"]
            if total_records.positive?
              results = parsed_json["results"]
              CommonUtils.instance.print_msg(solution, "Resulting Logs for #{date_in_string} -> #{results}")
              results.each do |log_file_detail|
                logs_to_process[log_file_detail["name"]] = log_file_detail if ConfigHandler.instance.log_config.log_types_enabled.any? { |log_type| log_file_detail["name"].include? log_type }
              end
            else
              CommonUtils.instance.print_msg(solution, "Resulting Logs for #{date_in_string} -> NONE")
            end
          end
          logs_to_process
        end

        def download_and_extract_log(solution, target_path, file_name, relative_url, audit_map)
          audit_map = {} if audit_map.nil?
          conn_mgr = ConnectionManager.new
          headers = {
            "Content-Type" => CommonUtils::CONTENT_TYPE_TEXT,
            "Accept-Encoding" => "gzip, deflate",
            "Accept" => "text/plain,text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
          }
          response = conn_mgr.execute(relative_url, nil, headers, nil, CommonUtils::HTTP_GET, true)
          if !response.nil? && response.status >= 200 && response.status < 300
            log_file_name = file_name.chomp(".gz")
            ConfigHandler.instance.log_config.log_types_enabled.each do |log_type|
              log_file_name = "#{log_type}.log" if log_file_name.include? log_type
            end
            CommonUtils.instance.print_msg(solution, "Downloaded log #{relative_url} and extracting it to #{target_path}/#{solution}/#{log_file_name}")
            unzip = Unzip.new
            unzip.extract(solution, relative_url, target_path, log_file_name, response.body)
          end
        end

      end
    end
  end
end

