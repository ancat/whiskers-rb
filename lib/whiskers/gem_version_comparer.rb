require 'fileutils'
require 'open-uri'
require 'rubygems/package'
require 'tmpdir'

module Whiskers
  class GemVersionComparer
    TMP_DIR = '/tmp/gems'

    def initialize(gem_name, old_version, new_version)
      @gem_name = gem_name
      @old_version = old_version
      @new_version = new_version
      FileUtils.mkdir_p(TMP_DIR)
      download_and_extract_gems
    end

    def old_dir
      base_dir(@old_version)
    end

    def new_dir
      base_dir(@new_version)
    end

    def base_dir(version)
      output_dir = File.join(TMP_DIR, "#{@gem_name}-#{version}")
      if Dir.exist?(output_dir)
        output_dir
      else
        raise "Gem directory not found: #{output_dir}"
      end
    end

    private

    def download_and_extract_gems
      [@old_version, @new_version].each do |version|
        gem_path = download_gem(version)
        extract_gem(gem_path, version)
      end
    end

    def download_gem(version)
      gem_file = "#{@gem_name}-#{version}.gem"
      gem_path = File.join(TMP_DIR, gem_file)
      
      unless File.exist?(gem_path)
        uri = URI.parse("https://rubygems.org/downloads/#{gem_file}")
        File.write(gem_path, uri.read)
      end
      
      gem_path
    end

    def extract_gem(gem_path, version)
      output_dir = File.join(TMP_DIR, "#{@gem_name}-#{version}")
      return if Dir.exist?(output_dir) && !Dir.empty?(output_dir)

      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
      
      # First, extract the gem file
      temp_dir = File.join(TMP_DIR, "temp_#{@gem_name}-#{version}")
      FileUtils.rm_rf(temp_dir)
      FileUtils.mkdir_p(temp_dir)
      system("tar", "xzf", gem_path, "-C", temp_dir)

      # Then extract data.tar.gz to the final location
      data_tar = File.join(temp_dir, "data.tar.gz")
      if File.exist?(data_tar)
        system("tar", "xzf", data_tar, "-C", output_dir)
        FileUtils.rm_rf(temp_dir)
      else
        FileUtils.mv(temp_dir, output_dir)
      end
    end
  end
end 