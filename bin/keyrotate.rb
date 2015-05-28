require 'openssl'
require 'pathname'
require 'fileutils'

last_key = Dir['keys/*'].map {|f| Pathname.new(f).basename.to_s.to_i}.sort.reverse.first
cipher = OpenSSL::Cipher.new('aes-256-gcm')
new_key = cipher.random_key
new_key_number = last_key + 1
key_path = "keys/#{new_key_number}"
open(key_path, 'w') {|f| f.write(new_key)}
FileUtils.ln_s(new_key_number.to_s, "keys/latest", :force => true)
