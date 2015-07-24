require 'minitest/autorun'
require 'fileutils'
require 'pathname'
require_relative '../lib/constants'

class TestUpload < Minitest::Test

  def cleanup
    FileUtils.rm_rf(UPLOADS)
    FileUtils.rm_rf(TOENCRYPT)
  end

  def test_shallow_upload
    cleanup
    filename = 'test'
    `curl -X POST -F 'file=@testfiles/testfile' localhost:9292/#{filename}`
    uploaded_files = Dir[File.join(UPLOADS, filename)]
    to_encrypt_files = Dir[File.join(TOENCRYPT, filename)]
    assert(uploaded_files.length == 1, "We uploaded 1 file.")
    assert(to_encrypt_files.length == 1, "There is one symlink waiting to be encrypted.")
    assert(uploaded_files.first[filename], "Name of the uploaded file matches what we uploaded.")
    assert(to_encrypt_files.first[filename], "Name of the symlink also matches.")
    cleanup
  end

  def test_one_level_deep_upload
    cleanup
    filename = 'a/test'
    `curl -X POST -F 'file=@testfiles/testfile' localhost:9292/#{filename}`
    uploaded_files = Dir[File.join(UPLOADS, filename)]
    to_encrypt_files = Dir[File.join(TOENCRYPT, filename)]
    assert(uploaded_files.length == 1, "We uploaded 1 file.")
    assert(to_encrypt_files.length == 1, "There is one symlink waiting to be encrypted.")
    assert(uploaded_files.first[filename], "Name of the uploaded file matches what we uploaded.")
    assert(to_encrypt_files.first[filename], "Name of the symlink also matches.")
    cleanup
  end

  def test_two_level_deep_upload
    cleanup
    filename = 'a/b/test'
    `curl -X POST -F 'file=@testfiles/testfile' localhost:9292/#{filename}`
    uploaded_files = Dir[File.join(UPLOADS, filename)]
    to_encrypt_files = Dir[File.join(TOENCRYPT, filename)]
    assert(uploaded_files.length == 1, "We uploaded 1 file.")
    assert(to_encrypt_files.length == 1, "There is one symlink waiting to be encrypted.")
    assert(uploaded_files.first[filename], "Name of the uploaded file matches what we uploaded.")
    assert(to_encrypt_files.first[filename], "Name of the symlink also matches.")
    cleanup
  end

end
