require 'test/unit'
require 'net/http'
require 'cgi'

class GemEvalTest < Test::Unit::TestCase
  def setup
    @pid = fork { exec("ruby gem_eval.rb") }
    sleep 0.5
  end

  def teardown
    Process.kill 9, @pid
  end

  def test_access_to_untainted_locals
    %w(repo data spec params).each do |v|
      assert_nil_error v
    end
  end

  def test_timeout
    puts "testing timeout..."
    begin
      timeout(7) do
        s = req <<-EOS
          def forever
            loop{}
          ensure
            forever
          end
          forever
        EOS
        assert_equal "ERROR: execution expired", s
      end
    rescue Timeout::Error
      fail "timed out! no good!"
    end
  end

  def test_legit_gemspec_works
    gemspec = <<-EOS
      Gem::Specification.new do |s|
        s.name = "name"
        s.description = 'description'
        s.version = "0.0.9"
        s.summary = ""
        s.authors = ["coderrr"]
        s.files = [ "x" ]
      end
    EOS
    expected_response = <<-EOS
--- !ruby/object:Gem::Specification 
name: name
version: !ruby/object:Gem::Version 
  version: 0.0.9
platform: ruby
authors: 
- coderrr
autorequire: 
bindir: bin
cert_chain: []

date: 2008-10-31 00:00:00 +07:00
default_executable: 
dependencies: []

description: description
email: 
executables: []

extensions: []

extra_rdoc_files: []

files: 
- x
has_rdoc: false
homepage: 
post_install_message: 
rdoc_options: []

require_paths: 
- lib
required_ruby_version: !ruby/object:Gem::Requirement 
  requirements: 
  - - ">="
    - !ruby/object:Gem::Version 
      version: "0"
  version: 
required_rubygems_version: !ruby/object:Gem::Requirement 
  requirements: 
  - - ">="
    - !ruby/object:Gem::Version 
      version: "0"
  version: 
requirements: []

rubyforge_project: 
rubygems_version: 1.3.0
signing_key: 
specification_version: 2
summary: ""
test_files: []
    EOS
    assert_equal expected_response.strip, req(gemspec).strip
  end

  def TODO_test_glob_works
  end

  private

  def assert_nil_error(v)
    assert req("#{v}.abc").include?("undefined method `abc' for nil"), "#{v} was not nil"
  end

  def req(data)
    Net::HTTP.start 'localhost', 4567 do |h|
      h.post('/', "data=#{CGI.escape data}").body 
    end
  end
end
