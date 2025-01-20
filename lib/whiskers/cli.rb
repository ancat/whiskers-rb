module Whiskers
  class CLI
    def self.run(args)
      new(args).run
    end

    def initialize(args)
      @args = args
    end

    def run
      validate_args
      differences = compare_versions
      display_differences(differences)
      scan_changes(differences) unless differences.values.all?(&:empty?)
    end

    private

    def validate_args
      unless @args.length == 3
        puts "Usage: gem_diff GEM_NAME VERSION1 VERSION2"
        exit 1
      end
    end

    def compare_versions
      gem_name, version1, version2 = @args
      comparer = GemVersionComparer.new(gem_name, version1, version2)
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
      end
    end

    def scan_changes(differences)
      puts "\nRunning Semgrep security scan on changed files..."
      gem_name, version1, version2 = @args
      comparer = GemVersionComparer.new(gem_name, version1, version2)
      
      # Get all files to scan in both versions
      old_files = differences[:modified].map { |f| File.join(comparer.base_dir(version1), f) }
      new_files = differences[:modified].map { |f| File.join(comparer.base_dir(version2), f) } + 
                  differences[:added].map { |f| File.join(comparer.base_dir(version2), f) }

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
        finding.relative_path(comparer.base_dir(version2))
      end

      if findings_by_file.empty?
        puts "No new security issues found in changed files."
      end

      findings_by_file.each do |file, findings|
        puts "\nNew security findings in #{file}:"
        findings.each { |finding| puts finding.display }
      end
    end
  end
end 