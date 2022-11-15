# frozen_string_literal: true

require 'rspec'

RSpec.describe RubyHttp2::Protocol::Http1_1 do
  describe '#get' do
    let(:response) { ''.b }
    let(:mock_socket) do
      MockSocket.new response
    end

    context 'when the response is a success with Content-Type' do
      let(:response) do
        "HTTP/1.0 200 OK\r\n" \
          "Server: MockServer/1.2.3\r\n" \
          "Content-Type: text/html; charset=utf-8\r\n" \
          "Content-Length: 11\r\n" \
          "\r\n" \
          'hello world'
      end

      it 'writes a successful http request' do
        subject.get(mock_socket, '/foo', headers: [])
        expected_request = "GET /foo HTTP/1.1\r\n\r\n"

        expect(mock_socket.write_data).to eq expected_request
      end

      it 'returns a successful response object' do
        response = subject.get(mock_socket, '/foo', headers: [])
        expected_headers = [
          ['Server', 'MockServer/1.2.3'],
          ['Content-Type', 'text/html; charset=utf-8'],
          %w[Content-Length 11]
        ]
        expect(response.status).to eq 200
        expect(response.status_text).to eq 'OK'
        expect(response.headers.to_a).to eq expected_headers
        expect(response.body).to eq 'hello world'
      end
    end
  end
end
