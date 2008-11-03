class LazyDir < Array
  OrigDir = Dir

  def initialize(method, args, block = nil)
    @method, @args, @block = method, args, block
  end

  # this method is meant to be called lazily after the $SAFE has reverted to 0
  def to_a
    raise SecurityError  unless %w([] glob).include? @method
    files = OrigDir.send(@method, *@args, &@block)

    # only return files within the current directory
    cur_dir = File.expand_path('.') + File::SEPARATOR
    files.reject do |f|
      File.expand_path(f) !~ %r{^#{cur_dir}}
    end
  end
  alias_method :to_ary, :to_a

  def to_yaml(opts = {})
    to_a.to_yaml(opts)
  end

  class << self
    # these methods are meant to be called with tainted data in a $SAFE >= 3
    %w(glob []).each do |method_name|
      define_method method_name do |*a|
        LazyDir.new method_name, a
      end
    end

    def method_missing m, *a, &b
      OrigDir.send m, *a, &b
    end
  end
end

LazyDir.freeze
