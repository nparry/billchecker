FROM ubuntu:14.04

RUN apt-get update && apt-get upgrade -y

RUN apt-get -y install phantomjs
RUN apt-get -y install ruby
RUN apt-get -y install ruby-dev
RUN apt-get -y install build-essential
RUN apt-get -y install libxslt-dev
RUN apt-get -y install libxml2-dev
RUN apt-get -y install zlib1g-dev

# Speed up Docker images rebuilding during dev
RUN gem install capybara --no-rdoc --no-ri
RUN gem install poltergeist --no-rdoc --no-ri
RUN gem install redis --no-rdoc --no-ri
RUN gem install encryptor --no-rdoc --no-ri
RUN gem install slack-ruby-bot --no-rdoc --no-ri

RUN mkdir -p /tmp/billchecker_gem
COPY . /tmp/billchecker_gem/
RUN cd /tmp/billchecker_gem && gem build billchecker.gemspec && gem install billchecker*.gem --no-rdoc --no-ri
RUN cd / && rm -rf /tmp/billchecker_gem

RUN adduser --system --shell /bin/bash billchecker
USER billchecker

