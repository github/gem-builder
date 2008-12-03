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
    repo   = params[:repo]
    data   = params[:data]
    tmpdir = "tmp/#{repo}"
    spec = nil

    Timeout::timeout(3) do
      `git clone --depth 1 git://github.com/#{repo} #{tmpdir}`

      pid = fork do
        begin
          r.close

          require File.dirname(__FILE__)+'/security'
          require File.dirname(__FILE__)+'/lazy_dir'
          Dir.chdir(tmpdir) do
            thread = Thread.new do
              eval <<-EOE
                BEGIN { # First in first out. Get this one exec'ed before the code below.
                  Object.class_eval do
                    remove_const :OrigDir rescue nil
                    OrigDir = Dir
                    remove_const :Dir
                    Dir = LazyDir
                  end
                  $SAFE = 3
                  OrigDir.set_safe_level
                }
                BEGIN { # This forces Ruby to ignore nested END {} blocks
                  begin
                    params = tmpdir = data = spec = repo = nil
                    # Pass data out using TLS
                    Thread.current[:spec] = (#{data})
                  ensure
                    Object.class_eval do
                      remove_const :Dir
                      Dir = OrigDir
                    end
                  end
                }
              EOE
            end.join
            Dir.set_safe_level
            spec = thread[:spec]
            spec.rubygems_version = Gem::RubyGemsVersion # make sure validation passes
            spec.validate
          end

          w.write YAML.dump(spec)
        rescue Object
          puts $!,$@

          w.write "ERROR: #$!"
        end
      end
      w.close

      Process.wait pid
      r.read
    end
  rescue Exception
    Process.kill 9, pid
    puts $!,$@

    "ERROR: #$!"
  ensure
    `rm -rf #{tmpdir}`  if tmpdir
  end
end
