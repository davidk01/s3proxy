require 'openssl'
require 'pathname'

last_key = Dir['keys/*'].select {|f| Pathname.new(f).basename.to_i}.sort.reverse.first
cipher = OpenSSL::Cipher.new('aes-256-gcm')
new_key = cipher.random_key
open("keys/#{last_key + 1}", 'w') {|f| f.write(new_key)}
