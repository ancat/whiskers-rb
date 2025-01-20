module Whiskers
  class GemfileLockParser
    def initialize(content)
      @content = content
    end

    def parse
      specs = []
      in_specs = false
      current_group = nil

      @content.each_line do |line|
        case line
        when /^GEM/
          current_group = :gem
        when /^PATH/
          current_group = :path
        when /^GIT/
          current_group = :git
        when /^PLATFORMS/
          current_group = :platforms
        when /^DEPENDENCIES/
          current_group = :dependencies
        when /^BUNDLED/
          current_group = :bundled
        when /^RUBY VERSION/
          current_group = :ruby
        when /^\s{4}\S/
          if current_group == :gem
            name, version = parse_spec_line(line)
            specs << Dependency.new(name, version)
          end
        end
      end

      specs
    end

    private

    def parse_spec_line(line)
      if line =~ /^\s{4}(\S+)\s\((.*)\)/
        [$1, $2]
      else
        line.strip.split(/\s+/, 2)
      end
    end
  end
end 