require 'twitter'

class BillStreamer
  def initialize(store, notifier)
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @store = store
    @notifier = notifier
  end

  def process_stream
    @log.info("Starting stream processing")
    twitter_streaming_client.user do |object|
      case object
      when Twitter::DirectMessage
        if object.sender.screen_name == @notifier.screen_name
          @log.info("Ignoring twitter DM that we sent ourself")
        else
          @log.info("Processing twitter DM item #{object}")
          @notifier.reply_to_inquiry(object.sender.screen_name, process_dm(object.text))
        end
      else
        @log.info("Ignoring twitter stream item #{object}")
      end
    end
  end

  private

  def process_dm(text)
    case text.downcase
    when "billstatus"
      [ non_zero_bill_balances, most_out_of_date_account ].flatten
    else
      ["Sorry, I don't understand that"]
    end
  end

  def non_zero_bill_balances
    non_zeros = @store.all_account_info.
      map { |name, info| [info[:display_name], @store.get_balance(name)] }.
      find_all { |pair| !pair.last.nil? && pair.last > 0.01 }.
      map { |pair| "#{pair.first} is #{pair.last}" }
    if non_zeros.empty?
      [ "All accounts have 0 balance" ]
    else
      non_zeros
    end
  end

  def most_out_of_date_account
    most_out_of_date = @store.all_account_info.
      map { |name, info| [info[:display_name], @store.get_last_check_time(name)] }.
      sort { |p1, p2| p1.last <=> p2.last }.
      first
    if most_out_of_date.nil?
      [ "Unable to determine most out of date account" ]
    else
      [ "Most out of date account is #{most_out_of_date.first} @ #{most_out_of_date.last}" ]
    end
  end

  def twitter_streaming_client
    Twitter::Streaming::Client.new { |config| @notifier.configure_twitter(config) }
  end
end
