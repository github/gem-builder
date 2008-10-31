class LazyDir < Array
  OrigDir = Dir

  def initialize(method, args, block = nil)
    @method, @args, @block = method, args, block
  end

  def to_a
    raise SecurityError  unless [:[], :glob].include? @method
    files = OrigDir.send(@method, *@args, &@block)

    # only return files within the current directory
    cur_dir = File.expand_path('.')
    files.reject do |f|
      File.expand_path(f) !~ %r{^#{cur_dir}}
    end
  end
  alias_method :to_ary, :to_a

  def to_yaml(opts = {})
    to_a.to_yaml(opts)
  end

  class << self
    define_method :glob do |*a|
      LazyDir.new :glob, a
    end

    define_method :[] do |*a|
      LazyDir.new :[], a
    end

    def method_missing m, *a, &b
      OrigDir.send m, *a, &b
    end
  end
end

LazyDir.freeze
