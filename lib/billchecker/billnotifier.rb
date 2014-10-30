require 'twitter'
require 'base64'
require 'json'

class BillNotifier
  def initialize(account_name, info)
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @display_name = info[:display_name] || account_name
    @config = begin
      JSON.parse(Base64.decode64(ENV["TWITTER_SETTINGS"]), :symbolize_names => true)
    rescue
      raise "Unable to decode TWITTER_SETTINGS"
    end
    @twitter = Twitter::REST::Client.new do |config|
      config.consumer_key        = @config[:consumer_key]
      config.consumer_secret     = @config[:consumer_secret]
      config.access_token        = @config[:access_token]
      config.access_token_secret = @config[:access_token_secret]
    end
  end

  def balance_unchanged(old_balance)
    @log.info("Balance for #{@display_name} unchanged at '#{old_balance}'")
  end

  def balance_changed(old_balance, new_balance)
    notify("Balance for #{@display_name} changed from '#{old_balance}' to '#{new_balance}'")
  end

  private

  def notify(msg)
    @log.info("Sending DM to #{@config[:user_to_notify]}: #{msg}")
    @twitter.create_direct_message(@config[:user_to_notify], msg)
  end
end
