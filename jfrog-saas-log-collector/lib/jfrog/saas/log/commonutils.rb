# frozen_string_literal: true

require "json"
require "date"
require "zlib"
require "stringio"

module Jfrog
  module Saas
    module Log
      class CommonUtils
        include Singleton
        HTTP_GET = "get"
        HTTP_PUT = "put"
        HTTP_PATCH = "patch"
        HTTP_DELETE = "delete"
        HTTP_POST = "post"
        CONTENT_TYPE_JSON = "application/json"
        CONTENT_TYPE_TEXT = "text/plain"
        CONTENT_TYPE_HDR = "Content-Type"

        def print_msg(message)
          print_msg_with_pp(message, false)
        end

        def pretty_print_msg(message)
          print_msg_with_pp(message, true)
        end

        def print_msg_with_pp(message, pretty_print)
          if !pretty_print
            puts "#{Time.now.getutc.strftime("%Y-%m-%d %H:%M:%S.%3N ")}#{Time.now.getutc.zone} #{message}"
          else
            puts "#{Time.now.getutc.strftime("%Y-%m-%d %H:%M:%S.%3N ")}#{Time.now.getutc.zone} - Formatted Message"
            pp message.to_s
            puts "\n"
          end
        end

        def get_log_url_for_date(solution, date_in_string)
          "artifactory/jfrog-logs/#{solution}/#{date_in_string}"
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

        def artifactory_aql_url
          "/#{ConfigHandler.instance.conn_config.end_point_base}/api/search/aql"
        end

        def artifactory_aql_body(solution, date_in_string)
          "items.find({\"repo\": \"jfrog-logs\", \"path\" : {\"$match\":\"#{solution}/#{date_in_string}\"}, \"name\" : {\"$match\":\"*log.gz\"}})"
        end

        def generate_dates_list(start_date_str, end_date_str)
          dates_list = []
          start_date = parse_date(start_date_str)
          end_date = parse_date(end_date_str)
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

        def parse_date(date_in_str)
          date_pattern = if ConfigHandler.instance.log_config.uri_date_pattern.nil?
                           "%Y-%m-%d"
                         else
                           ConfigHandler.instance.log_config.uri_date_pattern
                         end
          Date.strptime(date_in_str, date_pattern)
        rescue ArgumentError => e
          CommonUtils.instance.print_msg("Error occurred while parsing date : #{e.message}, setting current date")
          Date.today
        end

        def logs_to_process_between(start_date_str, end_date_str)
          generate_dates_list(start_date_str, end_date_str)
        end

        # 3. Download each log and update the audit repo with download details
        # 4. Once all the downloads are complete use the same list to perform extraction or deflate it post download to the target location

        def logs_to_process_hash(solution, date_in_string)
          logs_to_process = {}
          conn_mgr = ConnectionManager.new
          body = artifactory_aql_body(solution, date_in_string)
          headers = { "Content-Type" => CommonUtils::CONTENT_TYPE_TEXT }
          CommonUtils.instance.print_msg("Fetching list of logs from AQL with params -> #{body}")
          response = conn_mgr.execute(artifactory_aql_url, nil, headers, body, CommonUtils::HTTP_POST, false)
          if !response.nil? && (response.status >= 200 && response.status < 300) && response.headers[CommonUtils::CONTENT_TYPE_HDR] == CommonUtils::CONTENT_TYPE_JSON
            parsed_json = JSON.parse(response.body)
            total_records = parsed_json["range"]["total"]
            if total_records.positive?
              results = parsed_json["results"]
              CommonUtils.instance.print_msg("Resulting Logs for #{date_in_string} -> #{results}")
              results.each do |log_file_detail|
                logs_to_process[log_file_detail["name"]] = log_file_detail if ConfigHandler.instance.log_config.log_types_enabled.any? { |log_type| log_file_detail["name"].include? log_type }
              end
            end
          end
          logs_to_process
        end

        def download_and_extract_log(target_path, file_name, relative_url, audit_map)
          audit_map = {} if audit_map.nil?
          conn_mgr = ConnectionManager.new
          headers = {
            "Accept-Encoding": "gzip, deflate",
            "Accept": "text/plain,text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
          }
          response = conn_mgr.execute(relative_url, nil, headers, nil, CommonUtils::HTTP_GET, true)
          if !response.nil? && response.status >= 200 && response.status < 300
            log_file_name = file_name.chomp(".gz")
            ConfigHandler.instance.log_config.log_types_enabled.each do |log_type|
              log_file_name = "#{log_type}.log" if log_file_name.include? log_type
            end

            CommonUtils.instance.print_msg("Downloaded log #{relative_url} and extracting it to #{target_path}/#{log_file_name} ")

            File.open("#{target_path}/#{log_file_name}", "a") do |fp|
              fp.write(Zlib::GzipReader.new(StringIO.new(response.body)).read)
            end
            CommonUtils.instance.print_msg("Extracted log #{relative_url} successfully appended the content to #{target_path}/#{log_file_name}")
          end
        end

      end
    end
  end
end

