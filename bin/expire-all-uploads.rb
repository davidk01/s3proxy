require 'find'
require 'pathname'
require_relative '../lib/constants'

accumulator = []
Find.find(UPLOADS) do |f|
  if File.directory?(f) || File.symlink?(f)
    next
  end
  accumulator << f.sub(Pathname.new(File.join(UPLOADS, '/')).cleanpath.to_s, '')
  if accumulator.length > 1000
    `ruby bin/expire.rb -f #{accumulator.join(' ')}`
    accumulator = []
  end
end
