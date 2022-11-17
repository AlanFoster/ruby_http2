require 'rspec'

RSpec.describe RubyHttp2::Protocol::Http2 do
  describe RubyHttp2::Protocol::Http2::Model::Frame do
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
          payload: {
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
        }
        expect(described_class.read(data)).to eq(expected)
      end
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::SettingsFrame do
    let(:data) do
      "\x00\x03\x00\x00\x00d\x00\x04@\x00\x00\x00\x00\x02\x00\x00\x00\x00".b
    end

    it 'parses successfully' do
      expected = {
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
      subject = described_class.new({ frame_length: data.length })
      expect(subject.read(data)).to eq(expected)
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::WindowUpdateFrame do
    let(:data) do
      "\x00\x0f\x00\x01".b
    end

    it 'parses successfully' do
      expected = {
        window_size_increment: 983041
      }
      subject = described_class.new({ frame_length: data.length })
      expect(subject.read(data)).to eq(expected)
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::GoAwayFrame do
    let(:data) do
      "\x00\x00\x00\x00\x6b\x65\x65\x70\x2d\x61\x6c\x69\x76\x65\x20\x74\x69" \
        "\x6d\x65\x6f\x75\x74".b
    end

    it 'parses successfully' do
      expected = {
        error_code: 0,
        data: 'keep-alive timeout'.b
      }
      subject = described_class.new({ frame_length: data.length })
      expect(subject.read(data)).to eq(expected)
    end
  end

  describe RubyHttp2::Protocol::Http2::Model::UnknownFrame do
    let(:data) do
      "\x00\x00\x00\x01".b
    end

    it 'parses successfully' do
      expected = {
        data: "\x00\x00\x00\x01"
      }

      subject = described_class.new({ frame_length: data.length })
      expect(subject.read(data)).to eq(expected)
    end
  end
end
