require 'yaml'
CONFIG = YAML.load(File.read File.join(File.expand_path(File.dirname __FILE__), '../', 'config.yaml'))
BADSTRINGS = ['..', '?', '&', '|', ',', ';', '$', '(', ')', '[', ']', "'", '"']
# Private key path for openssl encryption/decryption
KEYS = 'keys'
PRIVATEKEY = File.join(KEYS, 'latest')
# Various directories for keeping track of uploaded and encrypted files
LOCKS = 'locks'
UPLOADS = 'uploads'
UPLOADING = 'uploading'
DECRYPTING = 'decrypting'
TOENCRYPT = 'to_encrypt'
TODECRYPT = 'to_decrypt'
ENCRYPTING = 'encrypting'
ENCRYPTED = 'encrypted'
# The S3 bucket were we upload encrypted artifacts
BUCKET = 'encrypted-artifacts'
