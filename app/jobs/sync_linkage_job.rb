# app/jobs/sync_linkage_job.rb

class SyncLinkageJob < ApplicationJob
  #include JobLogger  #app/lib/job_logger.rb

  queue_as :default

  def perform(linkage)
    begin
      set_status(linkage, :running)
      
      maybe_account = Account.find_by(id: linkage.maybe_account_id)
      simplefin_account = Account.find_by(id: linkage.simplefin_account_id)

      unless maybe_account && simplefin_account
        log(linkage, "Missing account(s)", :error)
        return set_status(linkage, :error)
      end

      log(linkage, "Maybe Account: '#{maybe_account.display_name}' [#{maybe_account.identifier}]; Type: #{maybe_account.accountable_type}")
      log(linkage, "SimpleFIN Account: '#{simplefin_account.display_name}' [#{simplefin_account.identifier}]")

      maybe_client = MaybeClientService.connect
      unless maybe_client
        log(linkage, "Failed to connect to Maybe PostgreSQL", :error)
        return set_status(linkage, :error)
      end

      username = Setting.find_by(key: 'simplefin_username')&.value
      password = Setting.find_by(key: 'simplefin_password')&.value

      unless username && password
        log(linkage, "Missing credentials for SimpleFIN", :error)
        return set_status(linkage, :error)
      end

      simplefin_client = SimplefinClient.new(username, password)

      lookback_days = Setting.find_by(key: 'lookback_days')&.value.to_i
      lookback_days = 7 if lookback_days.nil? || lookback_days <= 0  # Fallback to 7 if the value is nil or non-numeric
      lookback_date = (Time.now - (lookback_days * 24 * 60 * 60))
      start_date = lookback_date.to_i

      log(linkage, "Searching for Maybe transactions since #{lookback_date.strftime("%m/%d/%Y")}")
      transactions_in_maybe = maybe_client.get_simplefin_transactions(maybe_account.identifier, start_date)
      log(linkage, "Retrieved #{transactions_in_maybe.length} Maybe transactions")
      log(linkage, "Searching for SimpleFIN transactions since #{lookback_date.strftime("%m/%d/%Y")}")
      simplefin_response = simplefin_client.get_transactions(simplefin_account.identifier, start_date)
      
      if simplefin_response[:success]
        simplefin_account_with_balance = simplefin_response[:response]&.dig("accounts")&.first
        if simplefin_account_with_balance.nil?
          log(linkage, simplefin_response[:error_message], :error)
          return set_status(linkage, :error)
        end
        simplefin_transactions = simplefin_account_with_balance&.dig("transactions") || []
        log(linkage, "Retrieved #{simplefin_transactions.length} SimpleFIN transactions")
    
        simplefin_transactions.each do |simplefin_transaction|
          next if simplefin_transaction.nil?
          transaction_id = simplefin_transaction.dig("id")
    
          # If this transaction hasn't been synced yet, create a new transaction in Maybe
          unless transactions_in_maybe.any? { |t| t["plaid_id"] == transaction_id }

            if should_sync_transaction?(maybe_account.accountable_type, simplefin_transaction)
              log(linkage, "Adding transaction with plaid_id='#{transaction_id}'")
              currency = simplefin_account.currency.presence || maybe_account.currency.presence || "USD"
              amount = simplefin_transaction.dig("amount")
              short_date = simplefin_transaction.dig("posted")
              display_name = simplefin_transaction.dig("description")
              simplefin_txn_id = simplefin_transaction.dig("id")
              maybe_client.new_transaction(maybe_account.identifier, amount, short_date, display_name, simplefin_txn_id, currency, false)
            end
          end
        end
        if maybe_account.accountable_type == "Investment" # Investment
          log(linkage, "Updating Balance for '#{Time.at(simplefin_account_with_balance.dig("balance-date")).strftime("%m/%d/%Y")}'")
          maybe_client.upsert_account_valuation(maybe_account.identifier, simplefin_account_with_balance)
          
          # Sync holdings for investment accounts
          log(linkage, "Fetching holdings data from SimpleFIN")
          holdings_response = simplefin_client.get_holdings(simplefin_account.identifier)
          
          if holdings_response[:success] && holdings_response[:response]
            holdings_data = holdings_response[:response].dig("accounts")&.first&.dig("holdings")
            
            if holdings_data && holdings_data.any?
              log(linkage, "Syncing #{holdings_data.length} holdings")
              maybe_client.upsert_holdings(maybe_account.identifier, holdings_data)
              log(linkage, "Holdings sync completed")
            else
              log(linkage, "No holdings data found for investment account")
            end
          else
            log(linkage, "Failed to retrieve holdings from SimpleFIN: #{holdings_response[:error_message]}", :warn)
          end
        end
      else
        log(linkage, "Failed to retrieve data from SimpleFIN", :error)
        set_status(linkage, :error)
      end
      log(linkage, "Setting Linkage Status to 'Complete'")
      linkage.update(sync_status: :complete, last_sync: Time.current)
    rescue Net::ReadTimeout, ActiveRecord::StatementInvalid, NoMethodError => e
      log(linkage, "An error occurred: #{e.message}", :error)
      set_status(linkage, :error)
    rescue => e
      log(linkage, "Unexpected error occurred: #{e.message}", :error)
      set_status(linkage, :error)
    ensure
      maybe_client&.close
    end
  end

  private

  def log(linkage, message, level = :info)
    Rails.logger.public_send(level, "[#{linkage.id}] #{message}")
  end

  def set_status(linkage, status)
    linkage.update(sync_status: status)
    log(linkage, "Setting Linkage Status to '#{status}'")
  end

  def should_sync_transaction?(account_type, transaction)
    description = transaction.dig("description")
    amount = transaction.dig("amount").to_f
  
    return false unless description
  
    if account_type == "Investment"
      return true if description.match?(/(CONTRIBUTIONS|INTEREST PAYMENT|AUTO CLEARING HOUSE FUND)/i) && amount > 0
      return true if description.match?(/(RECORDKEEPING|MANAGEMENT|WRAP) FEE/i) && amount < 0
      return false
    end
  
    true
  end  
end
  