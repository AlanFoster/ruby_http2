FROM ruby:3.2.0-preview3-bullseye

WORKDIR /app

COPY Gemfile Gemfile.lock ruby_http2.gemspec ./
COPY lib/ruby_http2/version.rb ./lib/ruby_http2/version.rb
RUN bundle install

COPY . .
