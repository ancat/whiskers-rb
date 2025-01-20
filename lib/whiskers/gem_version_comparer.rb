require 'fileutils'
require 'open-uri'
require 'rubygems/package'

module Whiskers
  class GemVersionComparer
    TMP_DIR = '/tmp/gem_diffs'

    def initialize(gem_name, version1, version2)
      @dep1 = Dependency.new(gem_name, version1)
      @dep2 = Dependency.new(gem_name, version2)
      @base_dir1 = File.join(TMP_DIR, "#{gem_name}-#{version1}")
      @base_dir2 = File.join(TMP_DIR, "#{gem_name}-#{version2}")
    end

    def compare
      setup_directories
      download_and_extract_gems
      diff_files
    end

    def base_dir(version)
      version == @dep1.version ? @base_dir1 : @base_dir2
    end

    private

    def setup_directories
      FileUtils.mkdir_p(TMP_DIR)
      FileUtils.mkdir_p(@base_dir1)
      FileUtils.mkdir_p(@base_dir2)
    end

    def download_and_extract_gems
      download_and_extract(@dep1, @base_dir1)
      download_and_extract(@dep2, @base_dir2)
    end

    def download_and_extract(dependency, target_dir)
      gem_path = File.join(TMP_DIR, "#{dependency.name}-#{dependency.version}.gem")
      
      unless File.exist?(gem_path)
        URI.open(dependency.gem_download_url) do |remote_file|
          File.binwrite(gem_path, remote_file.read)
        end
      end

      if Dir.empty?(target_dir)
        Gem::Package.new(gem_path).extract_files(target_dir)
      end
    end

    def diff_files
      dir1_files = collect_files(@base_dir1)
      dir2_files = collect_files(@base_dir2)

      {
        added: dir2_files - dir1_files,
        removed: dir1_files - dir2_files,
        modified: find_modified_files(dir1_files & dir2_files)
      }
    end

    def collect_files(dir)
      Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH)
         .reject { |f| File.directory?(f) }
         .map { |f| f.sub("#{dir}/", '') }
    end

    def find_modified_files(common_files)
      common_files.select do |file|
        path1 = File.join(@base_dir1, file)
        path2 = File.join(@base_dir2, file)
        FileUtils.compare_file(path1, path2) == false
      end
    end
  end
end 