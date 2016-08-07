# frozen_string_literal: true

module Chip8
  class Program
    attr_reader :path

    def initialize(file)
      @log = Logging.get_logger 'program'

      @log.info 'Reading program data'

      @path = file

      @data = []

      File.open(file, "rb") do |file|
        until file.eof?
          instr = file.read(CPU::INSTRUCTION_SIZE)
          next if instr.size != CPU::INSTRUCTION_SIZE
          @data << instr.unpack('n')[0]
        end
      end

      @log.info "Program loaded: #{@data.size * CPU::INSTRUCTION_SIZE} bytes"
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
