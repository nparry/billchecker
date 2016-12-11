require 'slack-ruby-bot'

module BillStreamer
  def self.process_stream
    BillStreamerBot.instance.run
  end

  class BillStreamerBot < SlackRubyBot::App
  end

  class BillStatus < SlackRubyBot::Commands::Base
    def self.call(client, data, _)
      logger.info("Got billstatus message #{data.inspect}")
      user = client.users.find { |u| u['id'] == data.user }
      replies = if user && user['name'] == 'nparry'
                  [non_zero_bill_balances, most_out_of_date_account].flatten
                else
                  ['I am not the droid you are looking for']
                end
      replies.each do |reply|
        client.message text: reply, channel: data.channel
      end
    end

    def self.non_zero_bill_balances
      non_zeros = store.all_account_info
                       .map { |name, info| [info[:display_name], store.get_balance(name)] }
                       .find_all { |pair| !pair.last.nil? && pair.last > 0.01 }
                       .map { |pair| "#{pair.first} is #{pair.last}" }
      if non_zeros.empty?
        ['All accounts have 0 balance']
      else
        non_zeros
      end
    end

    def self.most_out_of_date_account
      most_out_of_date = store.all_account_info
                              .map { |name, info| [info[:display_name], store.get_last_check_time(name)] }
                              .sort_by(&:last)
                              .first
      if most_out_of_date.nil?
        ['Unable to determine most out of date account']
      else
        ["Most out of date account is #{most_out_of_date.first} @ #{most_out_of_date.last}"]
      end
    end

    def self.store
      @store ||= BillStore.new
    end
  end
end
