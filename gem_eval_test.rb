require 'test/unit'
require 'net/http'
require 'cgi'

OUTPUT = !!ENV['SERVER_OUTPUT']
if ! OUTPUT
  puts "gem_eval server output disabled, set SERVER_OUTPUT=1 to enable"
end

class GemEvalTest < Test::Unit::TestCase
  def setup
    @pid = fork { exec("ruby gem_eval.rb #{' > /dev/null 2>&1' unless OUTPUT}") }
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

  def test_gemspec_with_glob_works
    system("mkdir globdir && cd globdir && touch a.rb b.rb c.txt")
    gemspec = <<-EOS
      Gem::Specification.new do |s|
        s.name = "name"
        s.description = 'description'
        s.version = "0.0.9"
        s.summary = ""
        s.authors = ["coderrr"]
        s.files = Dir.glob("globdir/**.rb")
        s.test_files = Dir["globdir/**"]
        # make sure array globs work with .glob and make sure glob flags work
        s.executables = Dir.glob(["globdir/*.TXT", "globdir/*.RB"], File::FNM_CASEFOLD)
        # make sure array globs work with [] and make sure we cant access files in parent dirs
        s.extra_rdoc_files = Dir["/etc/*", "globdir"]
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
executables: 
- globdir/c.txt
- globdir/b.rb
- globdir/a.rb
extensions: []

extra_rdoc_files: 
- globdir
files: 
- globdir/b.rb
- globdir/a.rb
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
test_files: 
- globdir/b.rb
- globdir/a.rb
- globdir/c.txt
    EOS
    assert_equal expected_response.strip, req(gemspec).strip
  ensure
    system("rm -rf globdir")
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
