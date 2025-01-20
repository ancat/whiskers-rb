module Semgrep
  class Finding
    attr_reader :rule_id, :message, :lines, :line, :path

    def initialize(result)
      @rule_id = result["check_id"]
      @message = result["extra"]["message"]
      @lines = result["extra"]["lines"]
      @line = result["start"]["line"]
      @path = result["path"]
    end

    def ==(other)
      rule_id == other.rule_id && lines == other.lines
    end

    def display
      [
        "  [#{rule_id}] line #{line}: #{message}",
        "    #{lines}"
      ].join("\n")
    end

    def relative_path(base_dir)
      path.sub("#{base_dir}/", '')
    end
  end
end 