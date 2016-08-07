module Chip8
  module CPU
    class Registers
      V_COUNT = 16

      V_MASK = 0xFF

      I_MASK = 0xFFFF

      DT_MASK = 0xFF

      ST_MASK = 0xFF

      attr_reader :i, :dt, :st

      def initialize
        @log = Logging.get_logger 'regs'
        @v = [0] * V_COUNT
        @i = 0
        @dt = 0
        @st = 0
        @log.info 'Registers initialized'
      end

      def [](index)
        raise InvalidRegisterError.new(index) unless valid_v? index
        @v[index]
      end

      def []=(index, value)
        raise InvalidRegisterError.new(index) unless valid_v? index
        @v[index] = value & V_MASK
      end

      def i=(value)
        @i = value & I_MASK
      end

      def dt=(value)
        @dt = value & DT_MASK
      end

      def st=(value)
        @st = value & ST_MASK
      end

      def tick
        @dt -= 1 if @dt > 0
        @st -= 1 if @st > 0
      end

      private

      def valid_v?(index)
        index >= 0 && index < V_COUNT
      end
    end
  end
end
