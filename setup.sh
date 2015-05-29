#!/bin/bash

# Make sure s3proxy user exists
if [[ ! $(id s3proxy) ]]; then
  exit 1
fi

# Need s3cmd for uploading and downloading encrypted artifacts
if [[ ! $(which s3cmd) ]]; then
  exit 1
fi

# Need openssl for encryption and decryption
if [[ ! $(which openssl) ]]; then
  exit 1
fi

# Make sure s3cfg exists
if [[ ! -e /home/s3proxy/.s3cfg ]]; then
  echo "Did not find .s3cfg at /home/s3proxy/.s3cfg"
  exit 1
fi

# Need a private key for encryption/decryption
if [[ ! -e /opt/s3proxy/keys/latest ]]; then
  echo "Did not find private key /opt/s3proxy/keys/latest for encryption/decryption."
  exit 1
fi

# nginx
if [[ ! $(curl localhost:8080 | grep nginx) ]]; then
  echo "NGINX is not running. Make sure it is running on port 8080 and points to /opt/s3proxy/uploads for root path."
  exit 1
fi

# varnish
if [[ ! $(curl localhost | grep Varnish) ]]; then
  echo "Varnish not running. Make sure /etc/varnish/varnish.params has VARNISH_LISTEN_PORT=80"
  exit 1
fi

# Make sure things are owned by s3proxy user
chown -R s3proxy:s3proxy /opt/s3proxy

# Enable s3proxy.service
pushd /opt/s3proxy
cp systemd/system/s3proxy.service /usr/lib/systemd/system/s3proxy.service
systemctl enable /usr/lib/systemd/system/s3proxy.service
systemctl daemon-reload
popd
