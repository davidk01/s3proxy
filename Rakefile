desc "Remove some upload to_encrypt encrypting encrypted"
task :clean do |t|
  sh "rm -rf uploads/ to_encrypt/ encrypting/ encrypted/"
end

desc "Clean up encrypted encrypting and re-run the encryptor"
task :testencryption do |t|
  sh "rm -rf encrypted encrypting"
  sh "cp testfiles/testfile to_encrypt/test"
  sh "ruby bin/encryptor.rb"
end
