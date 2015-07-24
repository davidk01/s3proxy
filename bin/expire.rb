require 'bundler/setup'
require 'trollop'
require 'pathname'
require_relative '../lib/constants'

opts = Trollop::options do
  opt :file, "Locations of files relative to #{UPLOADS} directory",
    :required => true, :type => :strings, :multi => false
end

# Validate
paths = opts[:file].map {|f| Pathname.new(File.join(UPLOADS, f)).cleanpath}
paths.each do |p|
  raise StandardError, "File does not exist #{p}." unless p.exist?
  if p.symlink?
    filepath = Pathname.new(File.join(p.dirname, p.readlink)).cleanpath
    begin
      FileUtils.rm(filepath)
    rescue Exception => e
      STDERR.puts e
    end
  end
end

# Create the directory structure in TOENCRYPT and add the symlinks
opts[:file].each do |f|
  symlink_target = Pathname.new(File.join(File.expand_path(File.dirname __FILE__), '..', UPLOADS, f)).cleanpath
  symlink_source = Pathname.new(File.join(TOENCRYPT, f)).cleanpath
  if symlink_target.symlink?
    STDOUT.puts "Nothing to do for #{f} because it has already been expired once."
    FileUtils.rm(symlink_source)
    next
  end
  symlink_source_dir = symlink_source.dirname
  FileUtils.mkdir_p(symlink_source_dir) unless symlink_source_dir.exist?
  begin
    FileUtils.ln_s(symlink_target, symlink_source)
  rescue Exception => e
    STDERR.puts e
  end
end
