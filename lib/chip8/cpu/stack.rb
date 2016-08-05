module Chip8
  module CPU
    class Stack
      MAX_DEPTH = 16

      # An address in the stack is 16-bit, 2 bytes.
      ADDR_SIZE = 2

      attr_reader :depth

      def initialize(mem, offset)
        @mem = mem
        @offset = offset
        @depth = 0
      end

      def sp
        return Memory::END_INDEX if @depth == 0
        @offset + ADDR_SIZE * (@depth - 1)
      end

      def push(addr)
        raise StackOverflowError if @depth >= MAX_DEPTH
        @pointer = @offset
        @depth += 1
        @mem.write_array addr_to_arr(addr), sp
      end

      def pop
        raise InvalidAccessError, "Can't pop empty stack" if @depth == 0
        peek.tap { @depth -= 1 }
      end

      def peek
        arr_to_addr @mem.read_array(sp, ADDR_SIZE)
      end

      private

      def addr_to_arr(addr)
        [(addr >> 4), addr & 0xFF]
      end

      def arr_to_addr(arr)
        (arr[0] << 4) | arr[1]
      end
    end
  end
end
