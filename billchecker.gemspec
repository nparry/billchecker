Gem::Specification.new do |s|
  s.name        = 'billchecker'
  s.version     = '0.0.1'
  s.date        = '2014-10-21'
  s.authors     = [ 'Nathan Parry' ]
  s.summary     = 'Check utility account balances'

  s.files      += Dir.glob('lib/**/*')
  s.files      += Dir.glob('bin/**/*')

  s.executables << 'get-bill-balance'
  s.executables << 'store-billchecker-config'

  s.add_runtime_dependency 'capybara',  '~> 2.4'
  s.add_runtime_dependency 'poltergeist',  '~> 1.5'
  s.add_runtime_dependency 'redis',  '~> 3.1'
  s.add_runtime_dependency 'encryptor',  '~> 1.3.0'
  s.add_runtime_dependency 'twitter',  '~> 5.11.0'
end

