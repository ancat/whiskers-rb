require_relative 'whiskers/version'
require_relative 'whiskers/dependency'
require_relative 'whiskers/dependency_change'
require_relative 'whiskers/gemfile_lock_parser'
require_relative 'whiskers/gemfile_lock_diff'
require_relative 'whiskers/gem_version_comparer'
require_relative 'whiskers/cli'
require_relative 'semgrep'

module Whiskers
  class Error < StandardError; end
end 