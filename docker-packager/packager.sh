#!/bin/bash
package_version="0.1.0"
name="s3proxy"
ruby_version="2.2.2"

# install bundler and fpm because we are going to use them
# adds some fat to the package but not too big a deal
export PATH=/opt/ruby-${ruby_version}/bin:$PATH

# Copy shared folder into place, clean up some things, and install gems
mkdir ${name}
cp -r /code/* ${name}

pushd ${name}
rm -rf .*
rm -rf tests vagrant-integration-tests vagrant-packager vendor docker*
bundle package --all
bundle install --without test development --deployment
popd

# at this point we have a ruby in /opt/ruby-${ruby_version} and bundled gems and code in /${name}
# so time to package stuff up as an rpm
mv ${name} /opt

# package stuff with fpm
fpm -s dir -t rpm --name "${name}" --epoch 1 --maintainer 'davidk01' \
  --version ${package_version} \
  --depends nginx --depends s3cmd --depends varnish \
  /opt/ruby-${ruby_version} /opt/${name}

# Move it to shared directory
cp *.rpm /code
