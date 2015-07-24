require 'find'
require 'pathname'
require_relative '../lib/constants'

accumulator = []
Find.find(UPLOADS) do |f|
  if f.include?(BUCKET)
    Find.prune()
  end
  if File.directory?(f) || File.symlink?(f)
    next
  end
  accumulator << f.sub(Pathname.new(File.join(UPLOADS, '/')).cleanpath.to_s, '')
  if accumulator.length > 100
    `ruby bin/expire.rb -f #{accumulator.join(' ')}`
    accumulator = []
  end
end
`ruby bin/expire.rb -f #{accumulator.join(' ')}`
