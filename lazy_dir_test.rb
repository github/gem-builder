require 'test/unit'
require 'fileutils'
require File.dirname(__FILE__) + '/lazy_dir'

class LazyDirTest < Test::Unit::TestCase
  def setup
    FileUtils.mkdir('test_glob_dir')
    eval %{
      Object.class_eval do
        remove_const :Dir
        remove_const :OrigDir rescue nil
      end
      ::Dir = LazyDir
      ::OrigDir = LazyDir::OrigDir
    }
    %w(a b c d).each {|n| File.open("test_glob_dir/#{n}", 'w'){}}
  end

  def teardown
    eval %{
      Object.class_eval { remove_const :Dir }
      ::Dir = OrigDir
    }
    FileUtils.rm_r('test_glob_dir')
  end

  def test_lazy_glob
    assert_raises(SecurityError) do
      Thread.new do
        $SAFE=4
        OrigDir['test_glob_dir/*']
      end.join
    end

    lazy = Thread.new do
      $SAFE=4
      Dir['test_glob_dir/*']
    end.value

    assert_equal OrigDir['test_glob_dir/*'], lazy.to_a
    assert_equal OrigDir['test_glob_dir/*'], lazy.to_ary
  end

  def test_lazy_glob_flags
    assert LazyDir.glob('*/A').to_a.empty?
    assert_equal ['test_glob_dir/a'], LazyDir.glob('*/A', File::FNM_CASEFOLD).to_a
  end

  def test_lazy_glob_secure
    assert LazyDir['/etc/passwd'].to_a.empty?
    assert LazyDir['../../*'].to_a.empty?

    puts "\nbig glob test... this may take a while"
    orig = OrigDir['./**/*'].map {|f| File.expand_path(f) }
    lazy = LazyDir['../**/*'].to_a.map {|f| File.expand_path(f) }
    assert_equal orig, lazy
  end

  def test_lazy_dir_delegates_original_dir_methods
    assert Dir.pwd
    dir = 'asfasdfsaf' 
    assert Dir.mkdir(dir)
    assert File.exist?(dir)
    assert Dir.rmdir(dir)
    assert ! File.exist?(dir)
  end
end
