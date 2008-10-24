#!/usr/bin/env ruby

require 'rubygems'
require 'rubygems/specification'
require 'sinatra'
require 'timeout'
require 'yaml'

post '/' do
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
    YAML.dump spec
  rescue Object => e
    `rm -rf #{tmpdir}`
    puts e
    puts e.backtrace
    "ERROR: #{e}"
  end
end
