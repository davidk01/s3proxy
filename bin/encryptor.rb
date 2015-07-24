require 'bundler/setup'
require 'pathname'
require 'fileutils'
require 'openssl'
require 'trollop'
require 'thread'
require 'find'
require_relative '../lib/constants'

opts = Trollop::options do
  opt :procs, "Number of processes that will be uploading to S3",
    :required => true, :type => :int, :multi => false
end

queue = Queue.new
key_number = Pathname.new(PRIVATEKEY).readlink.to_s
key = File.read(File.join(KEYS, "#{key_number}"))
log = File.open('encryptor.log', 'w')

workers = (1..opts[:procs]).map do
  Thread.new do
    while true
      begin
        filename = queue.pop
        STDOUT.puts "Processing #{filename}."
        path = Pathname.new(filename).cleanpath
        encrypting_path = Pathname.new(path.to_s.sub(TOENCRYPT, File.join(ENCRYPTING, key_number))).cleanpath
        encrypted_path = Pathname.new(path.to_s.sub(TOENCRYPT, File.join(ENCRYPTED, key_number))).cleanpath
        upload_path = Pathname.new(path.to_s.sub(TOENCRYPT, UPLOADS)).cleanpath
        s3path = Pathname.new(File.join(BUCKET, encrypted_path.to_s.sub(ENCRYPTED, ''))).cleanpath
        iv_path = Pathname.new("#{encrypted_path}-iv").cleanpath
        lock = Pathname.new(path.to_s.sub(TOENCRYPT, LOCKS)).cleanpath
        directories = [encrypting_path.dirname, encrypted_path.dirname, iv_path.dirname, lock.dirname]
        directories.each {|dir| FileUtils.mkdir_p(dir) unless dir.exist?}
        File.open(lock, File::RDWR | File::CREAT, 0644) do |f|
          f.flock(File::LOCK_EX)
          cipher = OpenSSL::Cipher.new('aes-256-gcm')
          cipher.encrypt
          cipher.key = key
          iv = cipher.random_iv
          File.open(iv_path, 'w') {|f| f.write(iv)}
          data = File.read(path)
          encrypted_data = cipher.update(data) + cipher.final
          File.open(encrypting_path, 'w') {|f| f.write(encrypted_data)}
          FileUtils.mv(encrypting_path, encrypted_path, :force => true)
        end
        `s3cmd put -F '#{encrypted_path}' 's3://#{s3path}'`
        if $?.exitstatus > 0
          raise StandardError, "Something went wrong when uploading #{encrypted_path} to #{s3path}"
        end
        `s3cmd put -F '#{iv_path}' 's3://#{s3path}-iv'`
        if $?.exitstatus > 0
          raise StandardError, "Something went wrong when uploading IV #{iv_path}."
        end
        FileUtils.rm(encrypted_path, :force => true)
        FileUtils.rm(path, :force => true)
        FileUtils.rm(iv_path, :force => true)
        FileUtils.rm(upload_path, :force => true)
        FileUtils.ln_s(s3path, upload_path, :force => true)
      rescue Exception => e
        STDERR.puts e
      end
    end
  end
end

Find.find(TOENCRYPT).each do |f|
  if !File.directory?(f)
    queue.push(f)
    if queue.length > 100
      STDOUT.puts "Queue length too long sleeping 10 seconds."
      sleep 10
    end
  end
end

STDOUT.puts "Waiting for queue to drain."
while queue.length > 0
  initial = queue.length
  sleep 20
  final = queue.length
  if initial == final
    raise StandardError, "Queue size did not go down after 20s. Something is wrong."
  end
end
