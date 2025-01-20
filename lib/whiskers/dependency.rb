module Whiskers
  class Dependency
    attr_reader :name, :version

    def initialize(name, version)
      @name = name
      @version = version
    end

    def gem_download_url
      "https://rubygems.org/downloads/#{name}-#{version}.gem"
    end
  end
end 