module Whiskers
  module Commands
    class GemDiffBulk
      def initialize(args)
        @args = args
      end

      def run
        options = parse_options
        lockfile_changes = JSON.parse(File.read(options[:input]))
        mass_diff(lockfile_changes["changed"])
      end

      private

      # I need you to know I normally write much better code
      # and that this is just for testing
      def mass_diff(changed_gems)
        runner = Semgrep::Runner.new
        old_scan_targets = []
        new_scan_targets = []
        old_gem_paths = {}
        new_gem_paths = {}
        old_findings = {}
        new_findings = {}

        changed_gems.each do |g|
          old_dir = GemUtils.download_and_extract(g["name"], g["old_version"])
          new_dir = GemUtils.download_and_extract(g["name"], g["new_version"])
          old_gem_paths[old_dir] = g["name"]
          new_gem_paths[new_dir] = g["name"]
          changed_files = Semgrep::DirectoryDiffer.diff(old_dir, new_dir)
          files_of_interest = changed_files[:modified] + changed_files[:added]
          old_scan_targets << files_of_interest.map { |f| File.join(old_dir, f) if File.exist? File.join(old_dir, f) }
          new_scan_targets << files_of_interest.map { |f| File.join(new_dir, f) if File.exist? File.join(new_dir, f) }
        end

        old_scan_targets.flatten!
        old_scan_targets.compact!
        old_results = runner.scan(old_scan_targets)
        old_gem_paths.each do |gem_path, gem_name|
          old_findings[gem_name] = old_results.find_all { |f| f.path.start_with? gem_path }
          old_findings[gem_name].map { |f| f.rebase! gem_path }
        end

        new_scan_targets.flatten!
        new_scan_targets.compact!
        new_results = runner.scan(new_scan_targets)
        new_gem_paths.each do |gem_path, gem_name|
          new_findings[gem_name] = new_results.find_all { |f| f.path.start_with? gem_path }
          new_findings[gem_name].map { |f| f.rebase! gem_path }
        end

        findings_to_surface = {}
        new_findings.each do |gem_name, findings|
          findings_to_surface[gem_name] = []
          findings.each do |f|
            unless old_findings[gem_name].any? { |of| of.path == f.path && of.lines.gsub(/\s+/, "") == f.lines.gsub(/\s+/, "") || f.lines.strip.start_with?('#') }
              findings_to_surface[gem_name] << f
            end
          end
        end

        findings_to_surface.each do |gem_name, findings|
          next if findings.empty?

          puts "== #{gem_name} =="
          findings.each do |f|
            puts f.display
          end
        end
      end

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
