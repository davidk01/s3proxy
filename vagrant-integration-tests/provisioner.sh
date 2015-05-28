#!/bin/bash
if [[ ! $(ruby -v) ]]; then
  curl -sSL https://rvm.io/mpapis.asc | gpg --import -
  curl -sSL https://get.rvm.io | bash -s stable --ruby
  source /usr/local/rvm/scripts/rvm
  gem install bundler
fi

# Install nginx and s3cmd 
yum install -y epel-release
yum install -y nginx s3cmd vim lsof curl

# Clean up before copying anything
rm -rf *
cp -r /code/* .
# Make the required folders and symlinks for nginx
mkdir -p /opt/s3proxy
ln -s -T $(pwd)/uploads /opt/s3proxy/uploads

# Make a testfiles folder to hold test files. TODO: Use dd to generate files of various sizes
mkdir testfiles
echo a > testfiles/testfile

# Copy s3 configuration into place
cp s3cfg ~/.s3cfg

# Copy the nginx config into place and restart nginx
cp nginx/nginx.conf /etc/nginx/nginx.conf
service nginx restart

# Install all the dependencies for ruby and start the rack server
bundle install --deployment
bundle exec rackup -D
