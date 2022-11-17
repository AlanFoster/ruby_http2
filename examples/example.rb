#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'optparse'
require 'ruby_http2'
require 'json'
require 'logger'
require 'addressable'

protocols = %i[
  http1_1
  http2
]

options = {
  protocol: nil,
  ssl: nil,
  verbose: true,
  headers: [],
  # Whether to resolve addresses to ipv4 or ipv6
  resolve_hostname_preference: nil,
  sslkeylogfile: ENV.fetch('SSLKEYLOGFILE', nil),
  log_level: Logger::Severity::INFO
}

options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on('-h', '--help', 'Help banner') do
    return print(opts.help)
  end

  opts.on('--url=URL', 'The URL to use') do |url|
    url = Addressable::URI.parse(url)
    options[:url] = url
  end

  opts.on('--[no-]ssl', 'Use ssl') do |ssl|
    options[:ssl] = ssl
  end

  opts.on('--verbose', 'Enable verbose logging') do |verbose|
    options[:verbose] = verbose
  end

  protocols.each do |protocol|
    opts.on("--#{protocol}", "Negotiate with #{protocol}") do
      options[:protocols] ||= []
      options[:protocols] << :http2
    end
  end

  opts.on('--log-level=log_level', Integer, 'Log level') do |log_level|
    options[:log_level] = log_level
  end

  opts.on('--sslkeylogfile=sslkeylogfile', 'The sslkeylogfile to write to - useful for decrypting tls traffic in wireshark') do |sslkeylogfile|
    options[:sslkeylogfile] = sslkeylogfile
  end

  opts.on('-4', '--ipv4', 'Resolve names to IPv4 addresses') do
    options[:resolve_hostname_preference] = :ipv4
  end

  opts.on('-6', '--ipv6', 'Resolve names to IPv6 addresses') do
    options[:resolve_hostname_preference] = :ipv6
  end

  opts.on('--header=HEADER', 'An http header to send, i.e. "Host: example.com"') do |header|
    options[:headers] << header.split(': ', 2)
  end
end

options_parser.parse!

# default the protocol to the first supported protocol if not user-specified
options[:protocols] ||= [protocols.first]

if options[:url].nil?
  puts 'URL required'
  puts options_parser.help
  exit 1
end

logger = options[:verbose] ? Logger.new($stdout) : Logger.new(nil)
logger.level = options[:log_level]

logger.debug "Configuration: #{JSON.pretty_generate(options)}"

client = RubyHttp2::Client.new(
  url: options[:url],
  protocols: options[:protocols],
  ssl: options[:ssl],
  logger: logger,
  resolve_hostname_preference: options[:resolve_hostname_preference],
  sslkeylogfile: options[:sslkeylogfile]
)

pp client.get(
  options[:url],
  headers: options[:headers]
)
