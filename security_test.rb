# I dont use test/unit for this because the security measures screw with it
########

require File.dirname(__FILE__)+'/security'

def assert condition, message
  raise message  if ! condition

  print '.'; $stdout.flush
end

def assert_raises error, message, &block
  begin
    yield
    raise message
  rescue error
    print '.'; $stdout.flush
  end
end

['class Method', 'class UnboundMethod', 'module Kernel'].each do |klass|
  assert_raises TypeError, "#{klass} didn't raise" do
    eval("#{klass}; def x;end; end")
  end
end

data = 'echo YOU SHOULDNT SEE THIS!!!!'
['system(data)',
 'exec(data)',
 'Kernel.send(:exec,data)',
 'Object.new.exec(data)',
 '`#{data}`',
 'Kernel.`(data)',
 'Kernel.send(:`,data)',
 'trap(1,lambda{})',
 'fork{}',
 'callcc{}',
 'binding'
].each do |danger|
  assert_raises SecurityError, "#{danger} worked!" do
    eval danger
  end
end

Thread.new do
  $SAFE = 3
  Dir.set_safe_level
  assert_raises SecurityError, "snuck tainted string past glob" do
    Dir['**','**']
    Dir.glob(['**', '**'])
  end
end.join
Dir.set_safe_level
Dir['**'.taint]

dirs = Dir['/**']
assert(4 == (dirs & %w(/usr /bin /home /sbin)).size, 'glob doesnt work')

puts
