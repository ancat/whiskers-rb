module Whiskers
  class DependencyChange
    attr_reader :from, :to

    def initialize(from_dependency, to_dependency)
      @from = from_dependency
      @to = to_dependency
    end

    def to_s
      "#{from.name}: #{from.version} → #{to.version}"
    end
  end
end 