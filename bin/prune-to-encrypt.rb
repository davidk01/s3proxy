require_relative '../lib/constants'
require 'find'
require 'fileutils'

Find.find(TOENCRYPT).each do |f|
  next if File.directory?(f)
  link = File.readlink(f)
  if File.symlink?(link)
    STDOUT.puts "Removing link: #{f}."
    FileUtils.rm(link)
  end
end
