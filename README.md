# RubyHttp2

Simple http/http2 client written in Ruby to learn more about HTTP protocols.
Definitely not production ready or feature complete.

Implemented with the following references:
- http1.1 - https://httpwg.org/specs/rfc9110.html
- http2 - https://www.rfc-editor.org/rfc/rfc9113.html
- hpack overview for header compression - https://blog.cloudflare.com/hpack-the-silent-killer-feature-of-http-2/
- hpack header compression - https://www.rfc-editor.org/rfc/rfc7541#appendix-B

Note that in the context of http2, `endpoint` refers to either the client or server of the connection as per the spec.

## Usage

- First `git clone` the repository
- Either Install Ruby - via [rvm](https://rvm.io/) or similar, and run `bundle`
- Use docker: `docker-compose run service`

## Examples

### http 1.1 - port 80

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
  "... etc ..." +
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

### http 1.1 - ssl - port 443

```bash
$ SSLKEYLOGFILE=$(pwd)/sslkeylogfile ruby examples/example.rb --host example.com --port 443 --header 'Host: example.com' --ssl
Configuration: {
  "host": "example.com",
  "port": "443",
  "protocol": "http1_1",
  "ssl": true,
  "verbose": true,
  "path": "/",
  "headers": [
    "Host: example.com"
  ],
  "sslkeylogfile": "/app/sslkeylogfile",
  "log_level": 1
}
I, [2022-11-15T17:39:39.949583 #81]  INFO -- : connecting to #<Addrinfo: 93.184.216.34:443 TCP (example.com)>
#<RubyHttp2::Protocol::Http1_1::Response:0x00007f64264d4130
 @body=
  "<!doctype html>\n" +
  "<html>\n" +
    "... etc ..." +
  "</body>\n" +
  "</html>\n",
 @headers=
  #<RubyHttp2::Protocol::Http1_1::ResponseHeaders:0x00007f64264d5418
   @headers=
    [["Age", "137342"],
     ["Cache-Control", "max-age=604800"],
     ["Content-Type", "text/html; charset=UTF-8"],
     ["Date", "Tue, 15 Nov 2022 17:39:40 GMT"],
     ["Etag", "\"3147526947+ident\""],
     ["Expires", "Tue, 22 Nov 2022 17:39:40 GMT"],
     ["Last-Modified", "Thu, 17 Oct 2019 07:18:26 GMT"],
     ["Server", "ECS (dcb/7F84)"],
     ["Vary", "Accept-Encoding"],
     ["X-Cache", "HIT"],
     ["Content-Length", "1256"]]>,
 @status=200,
 @status_text="OK">
```

### http 2 - ssl - port 443

When the `--http2` option is specified, the SSL alpn will be set to `h2`. To gracefully fall back to `http1.1` support - the `--http1.1` flag must also be specified

```bash
$ SSLKEYLOGFILE=$(pwd)/sslkeylogfile ruby examples/example.rb --host example.com --port 443 --ssl --http2
```

## ipv4 / ipv6

When resolving hostnames you can specify the address family to preference:

- `-4` / `--ipv4` - Resolve names to IPv4 addresses
- `-6` / `--ipv6` - Resolve names to IPv6 addresses

## SSLKEYLOGFILE

If running with Ruby 3.2 - this tool honors curl's `SSLKEYLOGFILE` semantics, which allows for dissecting HTTPS/tls traffic with wireshark etc:

```bash
$ SSLKEYLOGFILE=$(pwd)/sslkeylogfile ruby examples/example.rb # ... options ...
```

This will create a new `sslkeylogfile` with data such as `CLIENT_RANDOM` in the nss file format 

Additional details:
- nss file format - https://firefox-source-docs.mozilla.org/security/nss/legacy/key_log_format/index.html
- curl example with wireshark dissector - https://daniel.haxx.se/blog/2018/01/15/inspect-curls-tls-traffic/

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
