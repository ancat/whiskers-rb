module Whiskers
  module Commands
    class GemDiff
      def initialize(args)
        @args = args
      end

      def run
        options = parse_options
        differences = compare_versions(options[:gem_name], options[:old_version], options[:new_version])
        display_differences(differences)
        scan_changes(differences, options) unless differences.values.all?(&:empty?)
      end

      private

      def parse_options
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

      def compare_versions(gem_name, old_version, new_version)
        comparer = GemVersionComparer.new(gem_name, old_version, new_version)
        Semgrep::DirectoryDiffer.diff(comparer.old_dir, comparer.new_dir)
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
        
        old_files = differences[:modified].map { |f| File.join(comparer.base_dir(options[:old_version]), f) }
        new_files = differences[:modified].map { |f| File.join(comparer.base_dir(options[:new_version]), f) } + 
                    differences[:added].map { |f| File.join(comparer.base_dir(options[:new_version]), f) }
        runner = Semgrep::Runner.new
        
        old_findings = runner.scan(old_files)
        new_findings = runner.scan(new_files)

        added_findings = new_findings.reject do |new_finding|
          old_findings.any? { |old_finding| new_finding == old_finding }
        end

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
end 
