# app/lib/simplefin_client.rb

require 'json'
require 'net/http'
require 'uri'

class SimplefinClient
  BASE_URL = "https://beta-bridge.simplefin.org/simplefin"  # SimpleFIN API base URL

  def initialize(username, password)
    @username = username
    @password = password
  end

  # Method to fetch all accounts, balances only
  def get_accounts
    query_params = {
      "balances-only" => 1,
      "start-date" => future_date
    }
    invoke_request("/accounts", query_params)
  end

  # Method to fetch single account, balances only
  def get_account(account_id)
    query_params = {
      "balances-only" => 1,
      "start-date" => future_date,
      "account" => account_id
    }
    invoke_request("/accounts", query_params)
  end

  # Method to fetch all transactions for a specific account within a date range
  def get_transactions(account_id, start_date)
    query_params = {
      "start-date" => start_date,
      "account" => account_id
    }
    invoke_request("/accounts", query_params)
  end

  # Method to fetch account holdings for investment accounts
  def get_holdings(account_id)
    query_params = {
      "account" => account_id,
      "start-date" => future_date  # Future date to avoid transactions, get holdings only
    }
    invoke_request("/accounts", query_params)
  end

  private

  def future_date
    (Time.now + (24 * 60 * 60)).to_i   #future date to avoid grabbing any transactions
  end

  # Helper method to make HTTP requests with basic authentication
  def invoke_request(endpoint, query_params = {})
    uri = URI.parse("#{BASE_URL}#{endpoint}")
    uri.query = URI.encode_www_form(query_params) unless query_params.empty?

    Rails.logger.info "Invoking HTTP GET on '#{uri}'"

    # Perform HTTP request with basic authentication
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(@username, @password)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 30, read_timeout: 30) do |http|
      http.request(request)
    end

    handle_response(response)

  rescue StandardError => e
    Rails.logger.error("HTTP Request failed: #{e.message}")
    {
      status_code: nil,
      response: nil,
      success: false,
      error_message: e.message
    }
  end

  # Handles API responses and errors, returns structured data
  def handle_response(response)
    parsed_body = JSON.parse(response.body) rescue nil
    success = response.code.to_i == 200

    unless success
      Rails.logger.error("SimpleFIN API Error: #{response.code} - #{parsed_body}")
    end

    # Return a structured hash with status code, response body, and success flag
    {
      status_code: response.code.to_i,
      response: parsed_body,
      success: success,
      error_message: parsed_body&.dig("errors")
    }
  end
end
