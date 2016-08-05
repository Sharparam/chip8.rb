# frozen_string_literal: true

module Chip8
  module Graphics
    class Sprite
      MAX_WIDTH = 8

      MAX_HEIGHT = 15

      def initialize(data)
        case data
        when Array
          init_from_array data
        when String
          init_from_string data
        else
          raise ArgumentError, 'Invalid sprite data type'
        end
      end

      def [](row, col)
        @data[row][col]
      end

      def size
        @data.size
      end

      def to_s
        @data.map { |r| r.map { |v| v ? '*' : ' ' }.join }.join "\n"
      end

      private

      def init_from_array(arr)
        raise ArgumentError, 'Too many bytes in sprite data' if arr.size > MAX_HEIGHT

        @data = arr.reduce([]) do |a, e|
          row = []
          MAX_WIDTH.times do |col|
            i = MAX_WIDTH - col - 1
            row[col] = ((e >> i) & 0x1) == 0x1
          end
          a << row
        end
      end

      def init_from_string(str)
        @data = str.split("\n").reduce([]) do |dat, line|
          dat << line.split('').map { |c| c == '*' }
        end
      end
    end
  end
end
