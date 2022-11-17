# RubyHttp2

Simple http/http2 client written in Ruby to learn more about HTTP protocols.
Definitely not production ready or feature complete.

Implemented with the following references:
- [http1.1 rfc9110](https://httpwg.org/specs/rfc9110.html)
- [http2 rfc9113](https://www.rfc-editor.org/rfc/rfc9113.html)
- [Cloudflare hpack overview for http2 header compression](https://blog.cloudflare.com/hpack-the-silent-killer-feature-of-http-2/)
- [hpack header compression rfc](https://www.rfc-editor.org/rfc/rfc7541) 

Note that in the context of http2, `endpoint` refers to either the client or server of the connection as per the spec.

## Usage

Either set up the gem locally with:

- First `git clone` the repository
- Install Ruby - via [rvm](https://rvm.io/) or similar
- Run `bundle` to install the required dependencies
- Run the examples shown below
  
Or use docker:
- `docker-compose run service`
- Run the examples shown below

## Examples

### Request http 1.1 - port 80

```bash
$ ruby examples/example.rb --url http://example.com --header 'Host: example.com' --ipv4 --verbose
I, [2022-11-17T19:48:56.568477 #123]  INFO -- : connecting to #<Addrinfo: 93.184.216.34:80 TCP (example.com)>
#<RubyHttp2::Protocol::Http1_1::Response:0x00007f6e8f359738
 @body=
  "<!doctype html>\n" +
  "<html>\n" +
  "<head>\n" +
  "    <title>Example Domain</title>\n" +
  "    ... etc...\n",
  "</html>\n",
 @headers=
  #<RubyHttp2::Protocol::Http1_1::ResponseHeaders:0x00007f6e8f35cf78
   @headers=
    [["Age", "478542"],
     ["Cache-Control", "max-age=604800"],
     ["Content-Type", "text/html; charset=UTF-8"],
     ["Date", "Thu, 17 Nov 2022 19:47:04 GMT"],
     ["Etag", "\"3147526947+ident\""],
     ["Expires", "Thu, 24 Nov 2022 19:47:04 GMT"],
     ["Last-Modified", "Thu, 17 Oct 2019 07:18:26 GMT"],
     ["Server", "ECS (dcb/7ECB)"],
     ["Vary", "Accept-Encoding"],
     ["X-Cache", "HIT"],
     ["Content-Length", "1256"]]>,
 @status=200,
 @status_text="OK">
```

### Request http 1.1 - ssl - port 443

```bash
$ SSLKEYLOGFILE=$(pwd)/sslkeylogfile ruby examples/example.rb --url https://example.com --header 'Host: example.com' --ipv6
I, [2022-11-17T20:14:39.531579 #21155]  INFO -- : connecting to #<Addrinfo: [2606:2800:220:1:248:1893:25c8:1946]:443 TCP (example.com)>
I, [2022-11-17T20:14:39.634258 #21155]  INFO -- : connection opened
I, [2022-11-17T20:14:39.879707 #21155]  INFO -- : server negotiated http/1.1
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

### Request http 2 - ssl - port 443

When the `--http2` option is specified, the SSL alpn will be set to `h2`:

```bash
$ SSLKEYLOGFILE=$(pwd)/sslkeylogfile ruby examples/example.rb --url https://example.com --http2 --ipv6 --verbose
I, [2022-11-17T22:00:54.197283 #21680]  INFO -- : connecting to #<Addrinfo: [2606:2800:220:1:248:1893:25c8:1946]:443 TCP (example.com)>
I, [2022-11-17T22:00:54.296489 #21680]  INFO -- : connection opened
I, [2022-11-17T22:00:54.328283 #21680]  INFO -- : configuring tls for http2
I, [2022-11-17T22:00:54.534100 #21680]  INFO -- : server negotiated h2
#<RubyHttp2::Protocol::Http2::Response:0x00007f9a2999b518
 @body=
  "<!doctype html>\n" +
  "<html>\n" +
    "... etc ..." +
  "</body>\n" +
  "</html>\n",
 @headers=
  [[":status", "200"],
   ["age", "534348"],
   ["cache-control", "max-age=604800"],
   ["content-type", "text/html; charset=UTF-8"],
   ["date", "Thu, 17 Nov 2022 22:00:54 GMT"],
   ["etag", "\"3147526947+ident\""],
   ["expires", "Thu, 24 Nov 2022 22:00:54 GMT"],
   ["last-modified", "Thu, 17 Oct 2019 07:18:26 GMT"],
   ["server", "ECS (dcb/7F7F)"],
   ["vary", "Accept-Encoding"],
   ["x-cache", "HIT"],
   ["content-length", "1256"]],
 @status="200",
 @status_text=nil>
```

To gracefully fall back to `http1.1` support, the `--http1.1` flag must also be specified

## ipv4 / ipv6

When resolving hostnames you can specify the address family to preference:

- `-4` / `--ipv4` - Resolve names to IPv4 addresses
- `-6` / `--ipv6` - Resolve names to IPv6 addresses

## SSLKEYLOGFILE

This tool honors curl's `SSLKEYLOGFILE` semantics, which allows for dissecting HTTPS/tls traffic with wireshark etc.
Ruby 3.2 is required for this functionality:

```bash
$ SSLKEYLOGFILE=$(pwd)/sslkeylogfile ruby examples/example.rb # ... options ...
```

This will create a new `sslkeylogfile` with data such as `CLIENT_RANDOM` in the nss file format

Additional details:
- nss file format - https://firefox-source-docs.mozilla.org/security/nss/legacy/key_log_format/index.html
- curl example with wireshark dissector - https://daniel.haxx.se/blog/2018/01/15/inspect-curls-tls-traffic/

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
