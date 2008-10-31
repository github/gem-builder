#!/usr/bin/env ruby

require 'rubygems'
require 'rubygems/specification'
require 'sinatra'
require 'timeout'
require 'yaml'

post '/' do
  r, w = IO.pipe

  pid = nil
  begin
    Timeout::timeout(3) do
      pid = fork do
        r.close

        require File.dirname(__FILE__)+'/security'
        require File.dirname(__FILE__)+'/lazy_dir'

        begin
          repo   = params[:repo]
          data   = params[:data]

          tmpdir = "tmp/#{repo}"
          spec   = nil

          `git clone --depth 1 git://github.com/#{repo} #{tmpdir}`
          Dir.chdir(tmpdir) do
            Thread.new do
              spec = eval <<-EOE
                begin
                  Object.class_eval do
                    remove_const :OrigDir rescue nil
                    OrigDir = Dir
                    remove_const :Dir
                    Dir = LazyDir
                  end
                  params = data = spec = repo = nil
                  $SAFE = 3
                  OrigDir.set_safe_level
                  #{data}
                ensure
                  Object.class_eval do
                    remove_const :Dir
                    Dir = OrigDir
                  end
                end
              EOE
            end.join
            Dir.set_safe_level
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
  rescue Timeout::Error
    Process.kill 9, pid
    puts $!,$@
    "ERROR: #{$!}"
  end

end
