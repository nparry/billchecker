Gem::Specification.new do |s|
  s.name        = 'billchecker'
  s.version     = '0.0.2'
  s.date        = '2014-10-21'
  s.authors     = ['Nathan Parry']
  s.summary     = 'Check utility account balances'

  s.files      += Dir.glob('lib/**/*')
  s.files      += Dir.glob('bin/**/*')

  s.executables << 'get-bill-balance'
  s.executables << 'store-billchecker-config'
  s.executables << 'process-bill-stream'

  s.add_runtime_dependency 'capybara', '~> 2.11'
  s.add_runtime_dependency 'poltergeist', '~> 1.12'
  s.add_runtime_dependency 'redis',  '~> 3.3'
  s.add_runtime_dependency 'encryptor',  '~> 3.0'
  s.add_runtime_dependency 'slack-ruby-bot', '~> 0.9'
  s.add_runtime_dependency 'faye-websocket', '~> 0.10'
  s.add_runtime_dependency 'bundler', '< 2.0'
end
