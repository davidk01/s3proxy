require 'rubygems'
require 'pathname'
require 'fileutils'
require 'digest/sha1'
require 'openssl'
require_relative '../lib/constants'

files = Dir[File.join(TOENCRYPT, '**', '*')]
key_digest = Digest::SHA1.hexdigest(File.read(PRIVATEKEY))
key = File.read(PRIVATEKEY)
# Acquire lock and encrypt the file into encrypting folder and then atomically move it into place
files.each do |filename|
  path = Pathname.new(filename).cleanpath
  if !path.directory?
    # All the paths
    encrypting_path = Pathname.new(path.to_s.sub(TOENCRYPT, File.join(ENCRYPTING, key_digest))).cleanpath
    encrypted_path = Pathname.new(path.to_s.sub(TOENCRYPT, File.join(ENCRYPTED, key_digest))).cleanpath
    iv_path = Pathname.new("#{encrypted_path}-iv").cleanpath
    lock = Pathname.new(path.to_s.sub(TOENCRYPT, LOCKS)).cleanpath
    # All the directories
    directories = [encrypting_path.dirname, encrypted_path.dirname, iv_path.dirname, lock.dirname]
    directories.each {|dir| FileUtils.mkdir_p(dir) unless dir.exist?}
    # Acquire the lock and then process the file
    File.open(lock, File::RDWR | File::CREAT, 0644) do |f|
      f.flock(File::LOCK_EX)
      if CONFIG['encryption']
        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.encrypt
        cipher.key = key
        iv = cipher.random_iv
        File.open(iv_path, 'w') {|f| f.write(iv)}
        data = File.read(path)
        encrypted_data = cipher.update(data) + cipher.final
        File.open(encrypting_path, 'w') {|f| f.write(encrypted_data)}
        FileUtils.mv(encrypting_path, encrypted_path, :force => true)
      else
        bin_dir = File.expand_path(File.dirname __FILE__)
        link_file = File.join(bin_dir, '..', encrypted_path)
        abs_path = File.join(bin_dir, '..', path)
        FileUtils.ln_s(abs_path, link_file, :force => true)
      end
    end
    # Upload encrypted artifact to S3 and and remove it from file system
    s3path = Pathname.new(File.join(BUCKET, encrypted_path.to_s.sub(ENCRYPTED, ''))).cleanpath
    if CONFIG['encryption']
      `s3cmd put -F '#{encrypted_path}' 's3://#{s3path}' && rm '#{encrypted_path}' && rm '#{path}'`
      `s3cmd put -F '#{iv_path}' 's3://#{s3path}-iv' && rm '#{iv_path}'`
    else
      `s3cmd put -F '#{encrypted_path}' 's3://#{s3path}' && rm '#{encrypted_path}' &7 rm '#{path}'`
    end
  end
end
