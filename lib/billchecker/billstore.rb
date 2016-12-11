require 'redis'
require 'json'
require 'openssl'
require 'encryptor'
require 'time'

class BillStore
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @redis = Redis.new
    @key = ENV['BILLSTORE_KEY']
    raise 'BILLSTORE_KEY must be specified' if @key.nil?
  end

  def get_account_info(name)
    @log.info("Retrieving account info for #{name}")
    data = @redis.hgetall(name)
    return nil if data.empty?
    info = JSON.parse(Encryptor.decrypt(data['value'], key: @key, iv: data['iv'], salt: data['salt']), symbolize_names: true)
    info[:display_name] = name unless info[:display_name]
    info
  end

  def all_account_info
    Hash[@redis.keys('*').map { |k| [k, get_account_info(k)] }]
  end

  def set_account_info(name, data)
    @log.info("Storing account info for #{name}")
    salt = Time.now.to_i.to_s
    iv = OpenSSL::Cipher::Cipher.new('aes-256-cbc').random_iv
    value = Encryptor.encrypt(JSON.generate(data), key: @key, iv: iv, salt: salt)
    @redis.hmset(name, 'value', value, 'iv', iv, 'salt', salt)
  end

  def get_balance(name)
    @log.info("Retrieving account balance for #{name}")
    value = @redis.hget(name, 'balance')
    @log.info("Found account balance #{value} for #{name}")
    value.to_f unless value.nil?
  end

  def get_last_check_time(name)
    @log.info("Retrieving last check timestamp for #{name}")
    value = @redis.hget(name, 'last_check')
    @log.info("Found last check timestamp #{value} for #{name}")
    Time.parse(value) unless value.nil?
  end

  def balance_unchanged(name)
    timestamp = Time.now
    @log.info("Updating last check timestamp to #{timestamp} for #{name}")
    @redis.hset(name, 'last_check', timestamp.to_s)
  end

  def balance_changed(name, value)
    timestamp = Time.now
    @log.info("Storing account balance #{value} with last check timestamp #{timestamp} for #{name}")
    @redis.hmset(name, 'balance', value.to_s, 'last_check', timestamp.to_s)
  end
end
