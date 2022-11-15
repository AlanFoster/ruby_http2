# frozen_string_literal: true

class MockSocket
  # @return [String] the data available to read
  attr_reader :read_data

  # @return [String] the data wrote to the socket
  attr_accessor :write_data

  def initialize(data)
    @read_data = data || +''.b
    @write_data = +''.b
  end

  def read(n)
    result = @read_data[0...n]
    remaining = @read_data[n..-1]
    @read_data = remaining || ''
    result
  end

  def write(value)
    @write_data << value
  end
end
