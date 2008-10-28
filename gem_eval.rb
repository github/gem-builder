#!/usr/bin/env ruby

require 'rubygems'
require 'rubygems/specification'
require 'sinatra'
require 'timeout'
require 'yaml'

post '/' do
  r, w = IO.pipe

  pid = fork do
    r.close

    Object.send :remove_const, :ObjectSpace

    class String
      %w(swapcase! strip! squeeze! reverse! downcase! upcase! delete! replace []= <<).each do |method_name|
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
        real_method = "__TAINTED__real__#{method_name}"
        call_method = "__TAINTED__call__#{method_name}"
     
        alias_method real_method, method_name
     
        m = instance_method(real_method)
        remove_method real_method
     
        define_method call_method do |b, *a|
          begin
            m.bind(self).call(*a, &b)
          ensure
            self.taint
          end
        end
     
        eval <<-EOF
          def #{method_name} *a, &b
            #{call_method}(b, *a)
          end
        EOF
      end
    end

    begin
      repo   = params[:repo]
      data   = params[:data]

      tmpdir = "tmp/#{repo}"
      spec   = nil

      `git clone --depth 1 git://github.com/#{repo} #{tmpdir}`
      Dir.chdir(tmpdir) do
        Timeout::timeout(3) do
          Thread.new { spec = eval("$SAFE = 3\n#{data}") }.join
        end
        spec.rubygems_version = Gem::RubyGemsVersion # make sure validation passes
        spec.validate
      end
      `rm -rf #{tmpdir}`
      w.write YAML.dump(spec)
    rescue Object => e
      `rm -rf #{tmpdir}`
      puts e
      puts e.backtrace
      w.write "ERROR: #{e}"
    end
  end
  w.close

  Process.wait pid
  r.read
end
