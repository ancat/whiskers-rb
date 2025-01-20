require 'digest'

module Semgrep
  class DirectoryDiffer
    def self.diff(old_dir, new_dir)
      old_dir = normalize_path(old_dir)
      new_dir = normalize_path(new_dir)

      old_files = Dir.glob(File.join(old_dir, "**/*")).select { |f| File.file?(f) }
      new_files = Dir.glob(File.join(new_dir, "**/*")).select { |f| File.file?(f) }

      old_relative = old_files.map { |f| f.sub("#{old_dir}/", '') }
      new_relative = new_files.map { |f| f.sub("#{new_dir}/", '') }

      common_files = old_relative & new_relative
      truly_modified = common_files.select do |file|
        old_checksum = Digest::SHA256.file(File.join(old_dir, file)).hexdigest
        new_checksum = Digest::SHA256.file(File.join(new_dir, file)).hexdigest
        old_checksum != new_checksum
      end

      {
        added: new_relative - old_relative,
        removed: old_relative - new_relative,
        modified: truly_modified
      }
    end

    private

    def self.normalize_path(path)
      # Remove trailing slashes
      # Convert multiple consecutive slashes to single slash
      # Expand relative paths (., ..)
      # Convert path to absolute path
      File.expand_path(path).gsub(%r{/+}, '/')
    end
  end
end 