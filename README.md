Upload files and then when necessary expire (`bin/expire.rb`), encrypt and upload (`bin/encryptor.rb`) them to S3. Varnish, nginx, and ruby provide all the necessary bits so that
the user is none the wiser where the requested files come from, disk or S3.
