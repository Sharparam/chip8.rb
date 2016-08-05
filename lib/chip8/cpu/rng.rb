module Chip8
  module CPU
    module RNG
      def self.generate
        rand 0..255
      end
    end
  end
end
