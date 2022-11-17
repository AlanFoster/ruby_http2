require 'rspec'

RSpec.describe RubyHttp2::Protocol::Http2 do
  describe RubyHttp2::Protocol::Http2::Model::OpaqueFrame do
    context 'when the frame is settings data' do
      let(:data) do
        "\x00\x00\x12\x04\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x64\x00" \
        "\x04\x40\x00\x00\x00\x00\x02\x00\x00\x00\x00".b
      end

      it 'parses successfully' do
        expected = {
          frame_length: 18,
          frame_type: 4,
          flags: 0,
          stream_identifier: 0,
          data: "\x00\x03\x00\x00\x00d\x00\x04@\x00\x00\x00\x00\x02\x00\x00\x00\x00".b
        }
        expect(described_class.read(data)).to eq(expected)
      end
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::SettingsFrame do
    let(:data) do
      "\x00\x00\x12\x04\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x64\x00" \
      "\x04\x40\x00\x00\x00\x00\x02\x00\x00\x00\x00".b
    end

    it 'parses successfully' do
      expected = {
        frame_length: 18,
        frame_type: 4,
        flags: 0,
        stream_identifier: 0,
        settings: [
          # Max concurrent streams
          {
            identifier: 3,
            setting_value: 100
          },
          # Initial window size
          {
            identifier: 4,
            setting_value: 1073741824
          },
          # Settings - enable push
          {
            identifier: 2,
            setting_value: 0
          },
        ]
      }
      expect(described_class.read(data)).to eq(expected)
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::WindowUpdateFrame do
    let(:data) do
      "\x00\x00\x04\x08\x00\x00\x00\x00\x00\x3f\xff\x00\x01".b
    end

    it 'parses successfully' do
      expected = {
        frame_length: 4,
        frame_type: 8,
        flags: 0,
        stream_identifier: 0,
        window_size_increment: 1073676289
      }
      expect(described_class.read(data)).to eq(expected)
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::GoAwayFrame do
    let(:data) do
      "\x00\x00\x19\x07\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" \
      "\x01\x53\x45\x54\x54\x49\x4e\x47\x53\x20\x65\x78\x70\x65\x63\x74" \
      "\x65\x64".b
    end

    it 'parses successfully' do
      expected = {
        frame_length: 25,
        frame_type: 7,
        flags: 0,
        stream_identifier:  0,
        error_code: 0,
        data: "\x00\x00\x00\x01SETTINGS expected".b
      }
      expect(described_class.read(data)).to eq(expected)
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::HeadersFrame do
    let(:data) do
      "\x00\x00\x0d\x01\x05\x00\x00\x00\x01\x82\x84\x87\x41\x88\x2f\x91" \
      "\xd3\x5d\x05\x5c\x87\xa7".b
    end

    it 'parses successfully' do
      expected = {
        frame_length: 13,
        frame_type: 1,
        priority: 0,
        padded: 0,
        end_headers: 1,
        end_stream: 1,
        stream_identifier:  1,
        field_block_fragment: "\x82\x84\x87A\x88/\x91\xD3]\x05\\\x87\xA7".b,
        padding: "".b
      }
      parsed = described_class.read(data)
      expect(parsed).to eq(expected)

      expected_headers = [
        %w[:method GET],
        %w[:path /],
        %w[:scheme https],
        %w[:authority example.com],
      ]
      expect(parsed.headers).to eq(expected_headers)
      expect(parsed.to_binary_s).to eq(data)
    end
  end
end
