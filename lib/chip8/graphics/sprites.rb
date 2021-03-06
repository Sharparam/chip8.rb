# frozen_string_literal: true

module Chip8
  module Graphics
    module Sprites
      STANDARD = [
        Sprite.new([0xF0, 0x90, 0x90, 0x90, 0xF0]),
        Sprite.new([0x20, 0x60, 0x20, 0x20, 0x70]),
        Sprite.new([0xF0, 0x10, 0xF0, 0x80, 0xF0]),
        Sprite.new([0xF0, 0x10, 0xF0, 0x10, 0xF0]),
        Sprite.new([0x90, 0x90, 0xF0, 0x10, 0x10]),
        Sprite.new([0xF0, 0x80, 0xF0, 0x10, 0xF0]),
        Sprite.new([0xF0, 0x80, 0xF0, 0x90, 0xF0]),
        Sprite.new([0xF0, 0x10, 0x20, 0x40, 0x40]),
        Sprite.new([0xF0, 0x90, 0xF0, 0x90, 0xF0]),
        Sprite.new([0xF0, 0x90, 0xF0, 0x10, 0xF0]),
        Sprite.new([0xF0, 0x90, 0xF0, 0x90, 0x90]),
        Sprite.new([0xE0, 0x90, 0xE0, 0x90, 0xE0]),
        Sprite.new([0xF0, 0x80, 0x80, 0x80, 0xF0]),
        Sprite.new([0xE0, 0x90, 0x90, 0x90, 0xE0]),
        Sprite.new([0xF0, 0x80, 0xF0, 0x80, 0xF0]),
        Sprite.new([0xF0, 0x80, 0xF0, 0x80, 0x80])
      ].freeze

      STANDARD_SIZE = 5

      def self.[](index)
        if index < 0 || index > 0xF
          raise ArgumentError, 'Invalid standard sprite requested'
        end

        STANDARD[index]
      end
    end
  end
end
