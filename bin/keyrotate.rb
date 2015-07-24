require 'openssl'
require 'pathname'
require 'fileutils'
require_relative '../lib/constants'

last_key = Dir[File.join(KEYS, '*')].map {|f| Pathname.new(f).basename.to_s.to_i}.sort.reverse.first
cipher = OpenSSL::Cipher.new('aes-256-gcm')
new_key = cipher.random_key
new_key_number = last_key + 1
key_path = File.join(KEYS, new_key_number.to_s)
open(key_path, 'w') {|f| f.write(new_key)}
FileUtils.ln_s(new_key_number.to_s, PRIVATEKEY, :force => true)
