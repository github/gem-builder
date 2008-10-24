#!/usr/bin/env ruby
require 'rubygems/specification'
require 'rubygems/builder'
require 'rubygems/package'
require 'fileutils'

class GemBuildError < StandardError
end

Gem::Builder.class_eval do
  def build(repository)
    @spec.mark_version
    @signer = sign
    write_package_with_git(repository)
  end

  def write_package_with_git(repository)
    tmp_path  = File.join('/data/github/gems', 'tmp',  @spec.file_name)
    gem_path  = File.join('/data/github/gems', 'gems', @spec.file_name)

    open(tmp_path, 'wb') do |gem_io|
      Gem::Package.open(gem_io, 'w', @signer) do |pkg|
        pkg.metadata = @spec.to_yaml
        @spec.files.each do |file|
          obj = repository.git.tree('master', file).contents.first rescue nil
          next if obj.nil? || obj.is_a?(Grit::Tree)
          mode = 0
          obj.mode.each_byte { |i| mode = (mode << 3) | i-'0'[0] }
          pkg.add_file_simple file, mode & 0777, obj.size do |tar_io|
            tar_io.write obj.data
          end
        end
      end
    end

    FileUtils.mv(tmp_path, gem_path, :force => true)
  end
end

def process(repository, path)
  return unless content = repository.git.tree('master', path).contents.first
  data = content.data
  
  if data !~ %r{!ruby/object:Gem::Specification}
    url  = URI.parse("http://gem_evaler:4567/")
    res  = Net::HTTP.post_form(url, { 'repo' => repository.name_with_owner, 'data' => data })
    data = res.body
    if data.include?('ERROR: ')
      data = data.sub('ERROR: ', '')
      Message.create \
        :to      => repository.owner,
        :from    => (User / :github),
        :subject => "[#{repository}] Gem Build Failure",
        :body    => "The gem build failed with the following error:\n\n#{data}"
      raise GemBuildError.new(data)
    end
  end

  spec = Gem::Specification.from_yaml(data)
  name = spec.name.gsub(' ', '-')
  spec.name = "#{repository.owner}-#{name}"
  Gem::Builder.new(spec).build(repository)
end

