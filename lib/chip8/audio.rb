# frozen_string_literal: true

require 'sdl'
require 'wavefile'

module Chip8
  module Audio
    class << self
      include WaveFile

      AMPLITUDE = 0.3
      LENGTH = 50
      CYCLES = 1
      FREQUENCY = 44100
      CHANNELS = 1
      CHUNKSIZE = 1024
      VOLUME = 16

      FILE = '/tmp/chip8.rb_beep.wav'

      def generate
        return @wave if @wave

        create
        init!

        @wave = SDL::Mixer::Wave.load(FILE).tap { |w| w.setVolume VOLUME }
      end

      def start
        if @started && @paused
          SDL::Mixer.resume 0
          @paused = false
        else
          SDL::Mixer.playChannel 0, generate, -1
          @started = true
        end
      end

      def stop
        return if @paused
        SDL::Mixer.pause 0
        @paused = true
      end

      def playing?
        !@paused && SDL::Mixer.play?(0)
      end

      private

      def log
        @log ||= Logging.get_logger 'audio'
      end

      def init!
        return if @inited
        SDL::Mixer.open FREQUENCY, SDL::Mixer::DEFAULT_FORMAT, CHANNELS, CHUNKSIZE
        @inited = true
      end

      def create
        return if File.exist? FILE

        cycle = ([AMPLITUDE] * LENGTH) + ([-AMPLITUDE] * LENGTH)
        buf = Buffer.new cycle * CYCLES, Format.new(:mono, :float, FREQUENCY)

        file = StringIO.new

        Writer.new FILE, Format.new(:mono, :pcm_16, FREQUENCY) do |writer|
          writer.write buf
        end
      end
    end
  end
end
