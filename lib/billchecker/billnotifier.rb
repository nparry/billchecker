class BillNotifier
  def initialize(account_name, info)
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @display_name = info[:display_name] || account_name
  end

  def balance_unchanged(old_balance)
    @log.info("Balance for #{@display_name} unchanged at '#{old_balance}'")
  end

  def balance_changed(old_balance, new_balance)
    @log.info("Balance for #{@display_name} changed from '#{old_balance}' to '#{new_balance}'")
  end
end
