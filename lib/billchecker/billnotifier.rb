require 'twitter'
require 'base64'
require 'json'

class BillNotifier
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @config = begin
      JSON.parse(Base64.decode64(ENV["TWITTER_SETTINGS"]), :symbolize_names => true)
    rescue
      raise "Unable to decode TWITTER_SETTINGS"
    end
  end

  def balance_unchanged(name, old_balance)
    @log.info("Balance for #{name} unchanged at '#{old_balance}'")
  end

  def balance_changed(name, old_balance, new_balance)
    notify(["Balance for #{name} changed from '#{old_balance}' to '#{new_balance}'"])
  end

  def reply_to_inquiry(sender, messages)
    if sender == @config[:user_to_notify]
      notify(messages)
    else
      @log.info("Ignoring inquiry from #{sender}, response was #{messages}")
    end
  end

  def configure_twitter(config)
    config.consumer_key        = @config[:consumer_key]
    config.consumer_secret     = @config[:consumer_secret]
    config.access_token        = @config[:access_token]
    config.access_token_secret = @config[:access_token_secret]
  end

  def screen_name
    @screen_name ||= twitter_rest_client.verify_credentials.screen_name
  end

  private

  def notify(messages)
    @log.info("Sending DM to #{@config[:user_to_notify]}: #{messages}")
    messages.each do |msg|
      twitter_rest_client.create_direct_message(@config[:user_to_notify], msg)
    end
  end

  def twitter_rest_client
    Twitter::REST::Client.new { |config| configure_twitter(config) }
  end
end
