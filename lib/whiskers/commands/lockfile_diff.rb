module Whiskers
  module Commands
    class LockfileDiff
      def initialize(args)
        @args = args
      end

      def run
        options = parse_options
        diff = GemfileLockDiff.new(options[:old_lockfile], options[:new_lockfile])

        if options[:json]
          display_json_output(diff)
        else
          display_text_output(diff)
        end
      end

      private

      def parse_options
        options = {}
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: whiskers lockfile_diff [options]"
          
          opts.separator ""
          opts.separator "Options:"

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            exit
          end

          opts.on("--json", "Output in JSON format") do
            options[:json] = true
          end

          opts.on("--old LOCKFILE", "Path to old Gemfile.lock") do |path|
            options[:old_lockfile] = path
          end

          opts.on("--new LOCKFILE", "Path to new Gemfile.lock") do |path|
            options[:new_lockfile] = path
          end
        end

        begin
          parser.parse!(@args)
        rescue OptionParser::InvalidOption => e
          puts "Error: #{e.message}"
          puts parser
          exit 1
        end

        unless options[:old_lockfile] && options[:new_lockfile]
          puts "Error: Both --old and --new lockfiles are required"
          puts parser
          exit 1
        end

        [options[:old_lockfile], options[:new_lockfile]].each do |file|
          unless File.exist?(file)
            puts "Error: File '#{file}' not found"
            exit 1
          end
        end

        options
      end

      def display_json_output(diff)
        output = {
          added: diff.new_dependencies.sort_by(&:name).map { |dep| 
            { name: dep.name, version: dep.version }
          },
          changed: diff.changed_dependencies.sort_by { |c| c.from.name }.map { |change|
            {
              name: change.from.name,
              old_version: change.from.version,
              new_version: change.to.version
            }
          }
        }
        puts JSON.pretty_generate(output)
      end

      def display_text_output(diff)
        if diff.new_dependencies.any?
          puts "\nAdded gems:"
          diff.new_dependencies.sort_by(&:name).each do |dep|
            puts "  + #{dep.name} (#{dep.version})"
          end
        end

        if diff.changed_dependencies.any?
          puts "\nChanged versions:"
          diff.changed_dependencies.sort_by { |c| c.from.name }.each do |change|
            puts "  ~ #{change.from.name}: #{change.from.version} → #{change.to.version}"
          end
        end

        if diff.new_dependencies.empty? && diff.changed_dependencies.empty?
          puts "No differences found between Gemfile.lock files"
        end
      end
    end
  end
end 