module Chip8
  class Program
    def initialize(file)
      @log = Logging.get_logger 'program'

      @data = []

      File.open(file, "rb") do |file|
        until file.eof?
          instr = file.read(2)
          next if instr.size != 2
          @data << instr.unpack('n')[0]
        end
      end
    end

    def [](index)
      @data[index]
    end

    def size
      @data.size
    end

    def each(&block)
      @data.each &block
    end

    def each_as_array
      each do |instr|
        yield [instr >> 8, instr & 0xFF]
      end
    end
  end
end
