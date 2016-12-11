require 'base64'
require 'json'

class BillNotifier
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @target_user = 'nparry'
  end

  def balance_unchanged(name, old_balance)
    @log.info("Balance for #{name} unchanged at '#{old_balance}'")
  end

  def balance_changed(name, old_balance, new_balance)
    notify(["Balance for #{name} changed from '#{old_balance}' to '#{new_balance}'"])
  end

  private

  def notify(messages)
    @log.info("Sending DM to #{@target_user}: #{messages}")
    messages.each do |msg|
      target_user = slack_client.users_list['members'].find { |user| user['name'] == @target_user }
      im = slack_client.im_list['ims'].find { |im| im['user'] == target_user['id'] }
      slack_client.chat_postMessage(channel: im['id'], text: msg, as_user: true)
    end
  end

  def slack_client
    @client ||= Slack::Web::Client.new(token: ENV['SLACK_API_TOKEN']).tap(&:auth_test)
  end
end
