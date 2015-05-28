#!/bin/bash
package_version="0.1.0"
name="s3proxy"
version="2.2.2"
dir="ruby-${version}"
if [[ ! -e ${dir} ]]; then
  wget http://cache.ruby-lang.org/pub/ruby/2.2/${dir}.tar.gz
  tar xf ${dir}.tar.gz
fi
echo "Cleaning up."
rm *.deb
rm *.rpm
rm -rf ${name}
rm -rf /opt/${name}

# install build tools
yum groupinstall -y "Development Tools" "Development Libraries"
# install development libraries
yum install -y openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel

# configure, make, install
if [[ ! -e /opt/ruby-${version} ]]; then
  pushd ruby-${version}
  ./configure --prefix=/opt/ruby-${version} --enable-load-relative --disable-install-capi --disable-debug --disable-dependency-tracking --disable-install-doc --enable-shared
  make -j
  make install
  popd
fi

# install bundler and fpm because we are going to use them
# adds some fat to the package but not too big a deal
export PATH=/opt/ruby-${version}/bin:$PATH
gem install bundler fpm --no-ri --no-rdoc

# Copy shared folder into place, clean up some things, and install gems
mkdir ${name}
cp -r /code/* ${name}

pushd ${name}
git clean -fxd
git reset --hard
rm -rf .*
rm -rf tests vagrant-integration-tests vagrant-packager vendor
rm private_key s3cfg s3-keys
bundle package --all
bundle install --without test development --deployment
popd

# at this point we have a ruby in /opt/ruby-${version} and bundled gems and code in /home/vagrant/${name}
# so time to package stuff up as an rpm
mv ${name} /opt

# package stuff with fpm
fpm -s dir -t rpm --name "${name}" --epoch 1 --maintainer 'davidk01@github' \
  --version ${package_version} \
  --depends nginx --depends s3cmd --depends varnish \
  /opt/ruby-${version} /opt/${name}

# Move it to shared directory
cp *.rpm /vagrant
