# remove dangerous methods
%w(` system exec trap fork callcc binding).each do |method|
  (class << Kernel; self; end).class_eval do
    remove_method method rescue nil
    undef_method method rescue nil
    define_method(method) {|*a| raise SecurityError }
  end
  Object.class_eval do
    remove_method method rescue nil
    undef_method method rescue nil
    define_method(method) {|*a| raise SecurityError }
  end
end
Kernel.freeze

# make sure all string methods which modify self also taint the string
class String
  %w(swapcase! strip! squeeze! reverse! downcase! upcase! delete! slice! replace []= <<).each do |method_name|
    m = instance_method(method_name)
    define_method method_name do |*args|
      begin
        m.bind(self).call *args
      ensure
        self.taint
      end
    end
  end
 
  %w(sub! gsub!).each do |method_name|
    m = instance_method(method_name)
 
    define_method "__real__#{method_name}" do |b, *a|
      begin
        m.bind(self).call(*a, &b)
      ensure
        self.taint
      end
    end
 
    eval <<-EOF
      def #{method_name} *a, &b
        __real__#{method_name}(b, *a)
      end
    EOF
  end
end



# Bug in ruby doesn't check taint when an array of globs is passed
class << Dir
  # we need to track $SAFE level manually because define_method captures the $SAFE level
  # of the current scope, as it would a local varaible, and of course the current scope has a $SAFE of 0
  @@safe_level = 0

  # since this method is defined with def instead of define_method, $SAFE will be taken from
  # the calling scope which is what we want
  def set_safe_level
    @@safe_level = $SAFE
  end

  %w([] glob).each do |method_name|
    m = instance_method method_name
    define_method method_name do |*args|
      $SAFE = @@safe_level
      raise SecurityError  if $SAFE >= 3 and args.flatten.any? {|a| a.tainted? }

      m.bind(self).call(*args)
    end
  end
end

# freeze String so that the taint method can't be redefined
String.freeze

# freeze Dir so that no one can modify the @@safe_level
Dir.freeze

# freeze method classes so someone cant modify them to catch the original methods
[Method, UnboundMethod].each {|klass| klass.freeze }

# disable ObjectSpace so people cant access the original method objects
Object.send :remove_const, :ObjectSpace
