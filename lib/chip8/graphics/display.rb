# frozen_string_literal: true

require 'sdl'

module Chip8
  module Graphics
    # The Display class assumes that `init_screen` has already been called.
    class Display
      WIDTH = 64

      HEIGHT = 32

      PIXEL_SIZE = 16

      BPP = 8

      def initialize
        @log = Logging.get_logger 'display'
        @log.info 'Display is initializing'

        @screen = []
        WIDTH.times { |r| @screen[r] = [false] * HEIGHT }

        @log.debug 'Opening SDL screen'

        @window = SDL::Screen.open PIXEL_SIZE * WIDTH, PIXEL_SIZE * HEIGHT, BPP,
                                   SDL::SWSURFACE | SDL::ANYFORMAT

        @log.debug 'Creating colors'

        @white = @window.mapRGB 255, 255, 255
        @black = @window.mapRGB 0, 0, 0

        @log.info 'Display initialized'
      end

      def [](x, y)
        @screen[x][y]
      end

      # Clears the screen, setting all pixels as blank.
      def clear
        @screen.each { |c| c.fill false }

        @window.fillRect 0, 0, WIDTH * PIXEL_SIZE, HEIGHT * PIXEL_SIZE, @black
        @window.updateRect 0, 0, WIDTH * PIXEL_SIZE, HEIGHT * PIXEL_SIZE
      end

      # Draws at the specified screen location. If the x or y parameters
      # are outside screen boundaries, they will wrap around.
      #
      # @return [Boolean] `true` if a previous pixel was erased.
      def draw(x, y, value)
        x = x % WIDTH
        y = y % HEIGHT

        old = self[x, y]

        @screen[x][y] ^= value

        draw_pixel x, y, self[x, y] ? @white : @black if old != self[x, y]

        old && !self[x, y]
      end

      # Draws the sprite at the specified location. If the sprite extends
      # past the screen boundary, it will wrap around to the opposite side.
      #
      # @param sprite [Sprite] The sprite to draw.
      # @param x [Fixnum] The X (column) position to draw at.
      # @param y [Fixnum] The Y (row) position to draw at.
      # @return [Boolean] `true` if there was a collision with any existing
      #   sprite, otherwise `false`.
      def draw_sprite(sprite, x, y)
        erased = false

        Sprite::MAX_WIDTH.times do |col|
          sprite.size.times do |row|
            e = draw(x + col, y + row, sprite[row, col])
            erased = e if e
          end
        end

        erased
      end

      def to_s
        lines = []
        HEIGHT.times { |r| lines[r] = [] }

        @screen.each_with_index do |column, x|
          column.each_with_index do |pixel, y|
            lines[y][x] = pixel ? '*' : ' '
          end
        end

        lines.map { |l| l.join }.join "\n"
      end

      private

      def draw_pixel(x, y, color)
        @window.fillRect x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE, color
        @window.updateRect x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE
      end
    end
  end
end
