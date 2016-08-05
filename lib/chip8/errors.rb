# frozen_string_literal: true

module Chip8
  class Chip8Error < RuntimeError
  end

  class MemoryError < Chip8Error
  end

  class InvalidAccessError < MemoryError
    attr_reader :index, :type

    def initialize(index, type)
      @index = index
      @type = type
    end
  end

  class StackOverflowError < MemoryError
  end

  class CpuError < Chip8Error
  end

  class InvalidRegisterError < CpuError
    attr_reader :index

    def initialize(index)
      @index = index
    end
  end

  class InstructionError < CpuError
    attr_reader :instruction

    def initialize(instruction)
      @instruction = instruction
    end
  end

  class UnsupportedInstructionError < InstructionError
  end
end
