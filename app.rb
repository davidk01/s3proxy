require 'rubygems'
require 'sinatra/base'
require 'pathname'
require 'fileutils'
require 'digest/sha1'
require 'yaml'
require_relative './lib/constants'
require 'shellwords'
require 'openssl'

class App < Sinatra::Base

  def check_and_escape_splat(splat)
    splat.any? do |component|
      if BADSTRINGS.any? {|str| component[str]}
        raise StandardError, "Bad path: #{splat.join('/')}"
      end
    end
    splat.map {|component| Shellwords.escape(component)}
  end

  ##
  # All the data for the file is in params['splat']. We are assuming the last element is the name of the file.
  
  post "/*" do 
    splat = check_and_escape_splat(params['splat'])
    path = Pathname.new(File.join(UPLOADS, *splat)).cleanpath
    encryption_path = Pathname.new(File.join(TOENCRYPT, *splat)).cleanpath
    uploading_path = Pathname.new(File.join(UPLOADING, *splat)).cleanpath
    lock = Pathname.new(File.join(LOCKS, *splat)).cleanpath
    filename = path.basename
    directories = [directory = path.dirname, lock_directory = lock.dirname, 
                   uploading_directory = uploading_path.dirname, 
                   encryption_directory = encryption_path.dirname]
    directories.each {|dir| FileUtils.mkdir_p(dir) unless dir.exist?}
    tempfile = params['file'][:tempfile]
    # Acquire the lock and then move things into place. Touch a transaction file
    # and remove it when symlink is created. Useful for crash recovery.
    File.open(lock, File::RDWR | File::CREAT, 0644) do |f|
      f.flock(File::LOCK_EX)
      FileUtils.touch(uploading_path)
      begin
        FileUtils.mv(tempfile, path, :force => true)
        FileUtils.chmod("go+r", path)
        symlink_source = Pathname.new(File.join(File.expand_path(File.dirname(__FILE__)), path)).cleanpath
      ensure
        FileUtils.rm(uploading_path)
      end
    end
    "File saved\n"
  end

  ##
  # Download the file, decrypt it, and put it in uploads/.

  get "/*" do
    splat = check_and_escape_splat(params['splat'])
    source = Pathname.new(File.join(*splat)).cleanpath
    decryption_source = Pathname.new(File.join(TODECRYPT, source)).cleanpath
    decryption_temp = Pathname.new(File.join(DECRYPTING, source)).cleanpath
    upload_destination = Pathname.new(File.join(UPLOADS, source)).cleanpath
    # If the path is not a symlink then there is no point in checking S3
    # because whenever we upload anything to S3 we leave a symlink in its place
    if !upload_destination.symlink?
      status 404
      return "We don't have a record of that file: #{source}."
    end
    marker_link = upload_destination.readlink
    marker_link_upload_path = Pathname.new(File.join(upload_destination, marker_link)).cleanpath
    directories = [decryption_directory = decryption_source.dirname, 
                   upload_directory = upload_destination.dirname, 
                   decryption_temp_dir = decryption_temp.dirname, 
                   marker_link_dir = marker_link_upload_path.dirname]
    directories.each {|dir| FileUtils.mkdir_p(dir) unless dir.exist?}
    # We need to figure out which key we used to encrypt the artifact
    s3_get_path = marker_link
    key = File.read(Pathname.new(File.join(KEYS, marker_link.to_s.split('/')[1])).cleanpath)
    `s3cmd get 's3://#{s3_get_path}' '#{decryption_source}'`
    `s3cmd get 's3://#{s3_get_path}-iv' '#{decryption_source}-iv'`
    if CONFIG['encryption']
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.key = key
      iv_path = "#{decryption_source}-iv"
      iv = File.read(iv_path)
      cipher.iv = iv
      encrypted_data = File.read(decryption_source)
      decrypted_data = cipher.update(encrypted_data)
      File.open(decryption_temp, 'w') {|f| f.write(decrypted_data)}
      FileUtils.mv(decryption_temp, marker_link_upload_path, :force => true)
      FileUtils.rm(decryption_source)
      FileUtils.rm(iv_path)
    else
      FileUtils.mv(decryption_source, marker_link_upload_path, :force => true)
    end
    send_file File.expand_path(upload_destination)
  end

end
