require 'logger'
require 'capybara'
require 'capybara/poltergeist'

Capybara.javascript_driver = :poltergeist
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    :js_errors => false,
    :phantomjs_options => ['--ignore-ssl-errors=yes']
  })
end

module BillChecker
  def self.session
    bc = BC.new
    begin
      yield bc
    ensure
      bc.shutdown
    end
  end

  private

  class BC
    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO
      @session = Capybara::Session.new(:poltergeist)
      @session.driver.add_headers('User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/600.6.3 (KHTML, like Gecko) Version/8.0.6 Safari/600.6.3')
    end

    def shutdown
      @session.driver.quit
    end

    def get_balance(account_info)
      case account_info[:type]
      when 'columbus'
        columbus_utility(account_info[:account_number])
      when 'columbia_gas'
        columbia_gas(account_info[:username], account_info[:password], account_info[:account_id])
      when 'wow'
        wow(account_info[:username], account_info[:password])
      else
        raise "Invalid account type in #{account_info}"
      end
    end

    private

    def columbus_utility(account_number)
      @session.visit 'https://webpay.columbus.gov/'
      @log.info('On Columbus Utility main page')

      @session.fill_in 'txtAccountNumber', :with => account_number
      @session.click_button 'Continue'
      row = @session.first 'tr', text: 'Current amount due'
      @log.info("Found info #{row} for account #{account_number}")

      row.all('td').last.text.to_f if row
    end

    def columbia_gas(username, password, account_id)
      @session.visit 'https://www.directlinkeservices.com/nisource/portal/oh'
      @log.info('On Columbia Gas main page')

      @session.fill_in 'userID', :with => username
      @session.fill_in 'password', :with => password
      @session.all('input').find { |el| el[:name] =~ /Submit/ }.click
      @log.info("Columbia Gas login complete for user #{username}")

      begin
        @session.select account_id
        @session.click_button 'GO'
        element = @session.all('.transactionInstructions').find { |el| el[:id] =~ /CurrentBalance/ }
        @log.info("Found info #{element} for account #{username}:#{account_id}")

        element.text.to_f if element
      ensure
        @session.click_link 'Log Out'
      end
    end

    def wow(username, password)
      @session.visit 'https://login.wowway.com/'
      @log.info('On WOW main page')

      @session.fill_in 'txtLoginUserName', :with => username
      @session.fill_in 'txtLoginPassword', :with => password
      @session.click_button 'imgbLogin'
      @log.info("WOW login complete for user #{username}")

      for i in 1..10
        break if @session.current_url.end_with? 'AccountSummary.aspx'
        sleep 1
      end
      raise 'Unable to login to WOW' unless @session.current_url.end_with? 'AccountSummary.aspx'

      begin
        for i in 1..10
          due = @session.first('#ctl00_MainContent_lblBS3_AmountDue')
          @log.info("Found info #{due} for account #{username}")

          return due.text.sub('$', '').to_f unless due.nil?
          sleep 1
        end
        raise 'Unable to locate WOW amount due'
      ensure
        @session.click_button 'ctl00_ctlHeader_imgbLogoutButton'
      end
    end
  end
end

