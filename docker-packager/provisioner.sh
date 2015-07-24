#!/bin/bash
yum -y install wget

package_version="0.1.0"
name="s3proxy"
version="2.2.2"
dir="ruby-${version}"
if [[ ! -e ${dir} ]]; then
  wget http://cache.ruby-lang.org/pub/ruby/2.2/${dir}.tar.gz
  tar xf ${dir}.tar.gz
fi

# install build tools
yum groupinstall -y "Development Tools" "Development Libraries"
# install development libraries
yum install -y openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel

# configure, make, install
if [[ ! -e /opt/ruby-${version} ]]; then
  pushd ruby-${version}
  ./configure --prefix=/opt/ruby-${version} --enable-load-relative --disable-install-capi --disable-debug --disable-dependency-tracking --disable-install-doc --enable-shared
  make -j4
  make install
  popd
fi

# install bundler and fpm because we are going to use them
# adds some fat to the package but not too big a deal
export PATH=/opt/ruby-${version}/bin:$PATH
gem install bundler fpm --no-ri --no-rdoc
