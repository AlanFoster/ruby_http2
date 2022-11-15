# RubyHttp2

Simple http/http2 client written in Ruby to learn more about HTTP protocols.
Definitely not production ready or feature complete.

Implemented following the spec:
- http1.1 - https://httpwg.org/specs/rfc9110.html
- http2 - https://www.rfc-editor.org/rfc/rfc9113.html

## Examples

Basic http 1.1 request:

```bash
$ ruby examples/example.rb --host example.com --port 80 --header 'Host: example.com'
Configuration: {
  "host": "example.com",
  "port": "80",
  "protocol": "http1_1",
  "ssl": false,
  "verbose": true,
  "headers": [
    "Host: example.com"
  ],
  "log_level": 1
}
I, [2022-11-15T00:10:51.320248 #77698]  INFO -- : connection opened
#<RubyHttp2::Protocol::Http1_1::Response:0x00007f9d70159f68
 @body=
  "<!doctype html>\n" +
   ... etc ...
  "</body>\n" +
  "</html>\n",
 @headers=
  #<RubyHttp2::Protocol::Http1_1::ResponseHeaders:0x00007f9d70149960
   @headers=
    [["Accept-Ranges", "bytes"],
     ["Age", "378075"],
     ["Cache-Control", "max-age=604800"],
     ["Content-Type", "text/html; charset=UTF-8"],
     ["Date", "Tue, 15 Nov 2022 00:10:51 GMT"],
     ["Etag", "\"3147526947+ident\""],
     ["Expires", "Tue, 22 Nov 2022 00:10:51 GMT"],
     ["Last-Modified", "Thu, 17 Oct 2019 07:18:26 GMT"],
     ["Server", "ECS (dcb/7EC9)"],
     ["Vary", "Accept-Encoding"],
     ["X-Cache", "HIT"],
     ["Content-Length", "1256"]]>,
 @status=200,
 @status_text="OK">
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_http2'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ruby_http2

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ruby_http2.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
