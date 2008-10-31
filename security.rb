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

# disable ObjectSpace
Object.send :remove_const, :ObjectSpace

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
 
    define_method "__call__#{method_name}" do |b, *a|
      begin
        m.bind(self).call(*a, &b)
      ensure
        self.taint
      end
    end
 
    eval <<-EOF
      def #{method_name} *a, &b
        __call__#{method_name}(b, *a)
      end
    EOF
  end
end

# freeze method classes so someone cant modify them to catch the original string methods
[Method, UnboundMethod].each {|klass| klass.freeze }
