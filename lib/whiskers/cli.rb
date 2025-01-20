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
        run_gem_diff
      when "lockfile_diff"
        run_lockfile_diff
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
      puts "  gem_diff      Compare two versions of a gem"
      puts "  lockfile_diff Compare two Gemfile.lock files"
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

    def run_gem_diff
      options = parse_gem_diff_options
      differences = compare_versions(options)
      display_differences(differences)
      scan_changes(differences, options) unless differences.values.all?(&:empty?)
    end

    def run_lockfile_diff
      options = parse_lockfile_diff_options
      diff = GemfileLockDiff.new(options[:old_lockfile], options[:new_lockfile])

      if options[:json]
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
      else
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

    def parse_gem_diff_options
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: whiskers gem_diff [options]"

        opts.separator ""
        opts.separator "Options:"

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit
        end

        opts.on("--gem NAME", "Name of the gem to compare") do |name|
          options[:gem_name] = name
        end

        opts.on("--old VERSION", "Old version of the gem") do |version|
          options[:old_version] = version
        end

        opts.on("--new VERSION", "New version of the gem") do |version|
          options[:new_version] = version
        end
      end

      begin
        parser.parse!(@args)
      rescue OptionParser::InvalidOption => e
        puts "Error: #{e.message}"
        puts parser
        exit 1
      end

      unless options[:gem_name] && options[:old_version] && options[:new_version]
        puts "Error: --gem, --old, and --new are all required"
        puts parser
        exit 1
      end

      options
    end

    def parse_lockfile_diff_options
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

      # Validate files exist
      [options[:old_lockfile], options[:new_lockfile]].each do |file|
        unless File.exist?(file)
          puts "Error: File '#{file}' not found"
          exit 1
        end
      end

      options
    end

    def compare_versions(options)
      comparer = GemVersionComparer.new(options[:gem_name], options[:old_version], options[:new_version])
      comparer.compare
    rescue OpenURI::HTTPError => e
      puts "Error downloading gem: #{e.message}"
      exit 1
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def display_differences(differences)
      if differences[:added].any?
        puts "\nAdded files:"
        differences[:added].each { |f| puts "  + #{f}" }
      end

      if differences[:removed].any?
        puts "\nRemoved files:"
        differences[:removed].each { |f| puts "  - #{f}" }
      end

      if differences[:modified].any?
        puts "\nModified files:"
        differences[:modified].each { |f| puts "  ~ #{f}" }
      end

      if differences.values.all?(&:empty?)
        puts "No differences found between versions"
      else
        changed_files = (differences[:added] + differences[:modified]).sort.join(',')
        puts "\nChanged files (comma-delimited):"
        puts changed_files
      end
    end

    def scan_changes(differences, options)
      puts "\nRunning Semgrep security scan on changed files..."
      comparer = GemVersionComparer.new(options[:gem_name], options[:old_version], options[:new_version])

      # Get all files to scan in both versions
      old_files = differences[:modified].map { |f| File.join(comparer.base_dir(options[:old_version]), f) }
      new_files = differences[:modified].map { |f| File.join(comparer.base_dir(options[:new_version]), f) } +
                  differences[:added].map { |f| File.join(comparer.base_dir(options[:new_version]), f) }

      runner = Semgrep::Runner.new
      
      # Run Semgrep on all files at once
      old_findings = runner.scan(old_files)
      new_findings = runner.scan(new_files)

      # Find new issues that weren't in the old version
      added_findings = new_findings.reject do |new_finding|
        old_findings.any? { |old_finding| new_finding == old_finding }
      end

      # Group and display findings
      findings_by_file = added_findings.group_by do |finding|
        finding.relative_path(comparer.base_dir(options[:new_version]))
      end

      findings_by_file.each do |file, findings|
        puts "\nNew security findings in #{file}:"
        findings.each { |finding| puts finding.display }
      end
    end
  end
end 