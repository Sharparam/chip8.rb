# frozen_string_literal: true

module Chip8
  class Memory
    START_INDEX = 0x000

    END_INDEX = 0xFFF

    PROG_INDEX = 0x200

    ELEM_MASK = 0xFF # One byte

    def initialize
      @log = Logging.get_logger 'mem'
      @mem = []
    end

    def self.truncate(value)
      value & ELEM_MASK
    end

    def [](index)
      if !valid_index? index
        raise InvalidAccessError.new(index, :read),
              'Tried to read invalid memory location.'
      end

      @mem[index]
    end

    def []=(index, value)
      if !valid_index? index
        raise InvalidAccessError.new(index, :write),
              'Tried to write to invalid memory location.'
      end

      @mem[index] = self.class.truncate value
    end

    def read_array(start, length)
      self[start..(start + length - 1)]
    end

    def write_array(arr, start)
      arr.size.times do |i|
        self[start + i] = arr[i]
      end
    end

    def write_sprite(sprite, start)
      data = []

      sprite.size.times do |row|
        data[row] = 0
        Graphics::Sprite::MAX_WIDTH.times do |col|
          value = sprite[row, col] ? 1 : 0
          shift = Graphics::Sprite::MAX_WIDTH - col - 1
          data[row] |= value << shift
        end
      end

      write_array data, start
    end

    private

    def valid_index?(index)
      case index
      when Range
        index.min >= START_INDEX && index.max <= END_INDEX
      else
        index >= START_INDEX && index <= END_INDEX
      end
    end
  end
end
