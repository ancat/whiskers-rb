require 'optparse'
require 'json'

module Whiskers
  class CLI
    def self.run(args)
      new(args).run
    end

    def initialize(args)
      @args = args
      @command = @args.shift
    end

    def run
      case @command
      when "gem_diff"
        Commands::GemDiff.new(@args).run
      when "lockfile_diff"
        Commands::LockfileDiff.new(@args).run
      when "gem_diff_bulk"
        Commands::GemDiffBulk.new(@args).run
      when "-h", "--help"
        show_help
      when "-v", "--version"
        show_version
      else
        show_help
        exit 1
      end
    end

    private

    def show_help
      puts "Usage: whiskers COMMAND [options]"
      puts
      puts "Commands:"
      puts "  gem_diff       Compare two versions of a gem"
      puts "  lockfile_diff  Compare two Gemfile.lock files"
      puts "  gem_diff_bulk  Compare multiple gems from a JSON file"
      puts
      puts "Options:"
      puts "  -h, --help     Show this help message"
      puts "  -v, --version  Show version"
      puts
      puts "See 'whiskers COMMAND --help' for more information on a specific command"
    end

    def show_version
      puts Whiskers::VERSION
    end
  end
end 