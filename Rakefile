desc "Remove to_encrypt, encrypting, encrypted, decrypting, to_decrypt, locks"
task :clean do |t|
  sh "systemctl stop s3proxy"
  sh "rm -rf to_encrypt/* encrypting/* encrypted/* locks/* uploading/*"
end

desc "Create a gzip of the symlinks in uploads/"
task :uploadbackup do |t|
  sh "find uploads/ -type l -printf '%p -> %l\n' | gzip > uploads.gz"
end

desc "Clean up encrypted encrypting and re-run the encryptor"
task :testencryption do |t|
  sh "rm -rf encrypted encrypting"
  sh "cp testfiles/testfile to_encrypt/test"
  sh "ruby bin/encryptor.rb"
end
