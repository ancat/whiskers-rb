module Semgrep
  class Runner
    def initialize(rules_path = "./semgrep-rules")
      @rules_path = rules_path
    end

    def scan(files)
      return [] if files.empty?
      
      cmd = [
        "semgrep",
        "--config", @rules_path,
        "--json",
        "--quiet",
        *files
      ]

      stdout, stderr, status = Open3.capture3(*cmd)
      
      if status.success?
        results = JSON.parse(stdout)["results"] rescue []
        results.map { |r| Finding.new(r) }
      else
        puts "Error running Semgrep: #{stderr}"
        []
      end
    end
  end
end 