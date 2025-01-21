require 'fileutils'
require 'open-uri'

module Whiskers
  class GemUtils
    TMP_DIR = '/tmp/gems'

    def self.download_and_extract(gem_name, version)
      FileUtils.mkdir_p(TMP_DIR)
      gem_path = download(gem_name, version)
      extract(gem_path, gem_name, version)
      output_dir = File.join(TMP_DIR, "#{gem_name}-#{version}")
      
      unless Dir.exist?(output_dir)
        raise "Failed to extract gem to #{output_dir}"
      end
      
      output_dir
    end

    private

    def self.download(gem_name, version)
      gem_file = "#{gem_name}-#{version}.gem"
      gem_path = File.join(TMP_DIR, gem_file)
      
      unless File.exist?(gem_path)
        uri = URI.parse("https://rubygems.org/downloads/#{gem_file}")
        File.write(gem_path, uri.read)
      end
      
      gem_path
    end

    def self.extract(gem_path, gem_name, version)
      output_dir = File.join(TMP_DIR, "#{gem_name}-#{version}")
      return if Dir.exist?(output_dir) && !Dir.empty?(output_dir)

      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
      
      # First, extract the gem file
      temp_dir = File.join(TMP_DIR, "temp_#{gem_name}-#{version}")
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
