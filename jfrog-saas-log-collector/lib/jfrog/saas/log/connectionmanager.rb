# frozen_string_literal: true

require "faraday"
require "faraday/net_http"
require "faraday/response"

require_relative "commonutils"

module Jfrog
  module Saas
    module Log
      class ConnectionManager
        # init and return the connection object
        def get_connection(jpd_url)
          Faraday.new(url: jpd_url) do |connection, request|
            connection.adapter Faraday::Adapter::NetHttp
            connection.use Faraday::Request::UrlEncoded
            connection.use Faraday::Response::Logger if ConfigHandler.instance.log_config.debug_mode == true
          end
        end

        def common_headers
          { "Authorization" => "Bearer #{ConfigHandler.instance.conn_config.access_token}" }
        end

        def additional_headers(additional_headers)
          additional_headers.merge(common_headers)
        end

        def execute(relative_url, params, headers, body, method)

          response = nil
          method = CommonUtils::HTTP_GET if method.nil?
          connection = get_connection(ConfigHandler.instance.conn_config.jpd_url)
          headers = if headers.nil?
                      common_headers
                    else
                      additional_headers(headers)
                    end
          if Faraday::METHODS_WITH_QUERY.include? method
            response = connection.get(relative_url, params, headers) if method == CommonUtils::HTTP_GET
            response = connection.delete(relative_url, params, headers) if method == CommonUtils::HTTP_DELETE
          elsif Faraday::METHODS_WITH_BODY.include? method
            response = connection.post(relative_url, body, headers) if method == CommonUtils::HTTP_POST
            response = connection.put(relative_url, body, headers) if method == CommonUtils::HTTP_PUT
            response = connection.patch(relative_url, body, headers) if method == CommonUtils::HTTP_PATCH
          end
          response
        rescue Faraday::SSLError, Faraday::ServerError, Faraday::ConnectionFailed => e
          CommonUtils.instance.print_msg("Error occurred while connecting to #{ConfigHandler.instance.conn_config.jpd_url}, error is -> #{e.message}")

        end

      end
    end
  end
end
