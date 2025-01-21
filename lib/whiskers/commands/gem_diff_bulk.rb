module Whiskers
  module Commands
    class GemDiffBulk
      def initialize(args)
        @args = args
      end

      def run
        options = parse_options
        input_file = options[:input]
        # TODO: Implement bulk gem diff functionality
        puts "Bulk gem diff not yet implemented"
      end

      private

      def parse_options
        options = {}
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: whiskers gem_diff_bulk [options]"
          
          opts.separator ""
          opts.separator "Options:"

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            exit
          end

          opts.on("--input FILE", "Path to JSON file containing gem changes") do |path|
            options[:input] = path
          end
        end

        begin
          parser.parse!(@args)
        rescue OptionParser::InvalidOption => e
          puts "Error: #{e.message}"
          puts parser
          exit 1
        end

        unless options[:input]
          puts "Error: --input file is required"
          puts parser
          exit 1
        end

        unless File.exist?(options[:input])
          puts "Error: Input file '#{options[:input]}' not found"
          exit 1
        end

        options
      end
    end
  end
end 
