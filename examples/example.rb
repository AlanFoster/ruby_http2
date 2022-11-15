#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'optparse'
require 'ruby_http2'
require 'json'
require 'logger'

protocols = %i[
  http1_1
  http2
]

options = {
  host: nil,
  port: nil,
  protocol: protocols.first,
  ssl: false,
  verbose: true,
  path: '/',
  headers: [],
  sslkeylogfile: ENV.fetch('SSLKEYLOGFILE', nil),
  log_level: Logger::Severity::INFO
}

options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options]"

  opts.on('-h', '--help', 'Help banner') do
    return print(opts.help)
  end

  opts.on('--host=HOST', 'The target host') do |host|
    options[:host] = host
  end

  opts.on('--port=PORT', 'The target port') do |port|
    options[:port] = port
    options[:ssl] = port == 443
  end

  opts.on('--[no-]ssl', 'Use ssl') do |ssl|
    options[:ssl] = ssl
  end

  opts.on('--verbose', 'Enable verbose logging') do |verbose|
    options[:verbose] = verbose
  end

  opts.on('--path=PATH', 'The http path') do |path|
    options[:path] = path
  end

  opts.on('--protocol=PROTOCOL', protocols, 'The protocol to use') do |protocol|
    options[:protocol] = protocol
  end

  opts.on('--log-level=log_level', Integer, 'Log level') do |log_level|
    options[:log_level] = log_level
  end

  opts.on('--sslkeylogfile=sslkeylogfile', 'The sslkeylogfile to write to - useful for decrypting tls traffic in wireshark') do |sslkeylogfile|
    options[:sslkeylogfile] = sslkeylogfile
  end


  opts.on('--header=HEADER', 'An http header to send, i.e. "Host: example.com"') do |header|
    options[:headers] += [header]
  end
end

options_parser.parse!

puts "Configuration: #{JSON.pretty_generate(options)}"

if options[:host].nil?
  puts 'Host required'
  puts options_parser.help
  exit 1
end

logger = options[:verbose] ? Logger.new($stdout) : Logger.new(nil)
logger.level = options[:log_level]
client = RubyHttp2::Client.new(
  host: options[:host],
  port: options[:port],
  protocol: options[:protocol],
  ssl: options[:ssl],
  logger: logger,
  sslkeylogfile: options[:sslkeylogfile]
)

pp client.get(options[:path], headers: options[:headers])
