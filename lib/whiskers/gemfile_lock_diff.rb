module Whiskers
  class GemfileLockDiff
    attr_reader :base_dependencies, :current_dependencies, :new_dependencies, :changed_dependencies

    def initialize(base_file_path, new_file_path)
      validate_files!(base_file_path, new_file_path)
      
      # Parse files and convert to Dependency objects
      @base_dependencies = parse_to_dependencies(base_file_path)
      @current_dependencies = parse_to_dependencies(new_file_path)
      
      # Calculate diffs
      calculate_diffs
    end

    def to_s
      output = []

      if new_dependencies.any?
        output << "\nAdded dependencies:"
        new_dependencies.each do |dep|
          output << "  + #{dep.name} (#{dep.version})"
        end
      end

      if changed_dependencies.any?
        output << "\nChanged versions:"
        changed_dependencies.each do |change|
          output << "  ~ #{change}"
        end
      end

      if new_dependencies.empty? && changed_dependencies.empty?
        output << "No dependencies were added or changed"
      end

      output.join("\n")
    end

    private

    def validate_files!(base_file_path, new_file_path)
      [base_file_path, new_file_path].each do |file_path|
        unless File.exist?(file_path)
          raise ArgumentError, "File '#{file_path}' not found"
        end
      end
    end

    def parse_to_dependencies(file_path)
      content = File.read(file_path)
      GemfileLockParser.new(content).parse
    end

    def calculate_diffs
      base_dep_hash = @base_dependencies.map { |dep| [dep.name, dep] }.to_h
      current_dep_hash = @current_dependencies.map { |dep| [dep.name, dep] }.to_h

      # Find added dependencies
      @new_dependencies = @current_dependencies.reject { |dep| base_dep_hash.key?(dep.name) }

      # Find changed dependencies
      @changed_dependencies = []
      current_dep_hash.each do |name, current_dep|
        base_dep = base_dep_hash[name]
        if base_dep && base_dep.version != current_dep.version
          @changed_dependencies << DependencyChange.new(base_dep, current_dep)
        end
      end
    end
  end
end 
