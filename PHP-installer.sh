#!/bin/bash

set -e
# Installing PHP from source
avail_versions=(8.0 7.4 7.3)
vernum=$1
threads=$2
if [[ ! " ${avail_versions[@]} " =~ " ${vernum} " ]]; then
	echo "Please choose one of the avaliable versions: 8.0, 7.4 or 7.3"
	exit
fi
version=php-"$vernum"
gitversion="$version".0
phpdir=/opt/"$version"

wget https://github.com/php/php-src/archive/"$gitversion".tar.gz -O /tmp/"$gitversion".tar.gz
tar -xf /tmp/"$gitversion".tar.gz -C /opt
mv /opt/php-src-"$gitversion" "$phpdir"
cd "$phpdir"
./buildconf --force
./configure --prefix="$phpdir"  \
	--with-openssl 		\
	--with-pear
make -j"$threads"
# make test --don't forget this
make install
echo "After make install"
phpini="$phpdir"/lib/php.ini
cp "$phpdir"/php.ini-production "$phpini" # make a copy once completed (with all installs, use this 'hidden copy' to compare against php.ini to check for modifications)
pecl="$phpdir"/bin/pecl
pear="$phpdir"/bin/pear
#"$pecl" config-set cache_dir /tmp/pear-"$version"/cache
"$pecl" config-set php_ini "$phpini"
"$pecl" update-channels
#"$pecl" upgrade-all
#if [[ "$vernum" == 7.3 ]]; then
#  echo "upgrading with xml"
#	"$pecl" upgrade --force xml_util # if 7.3.0 need to use --force xml_util
#else
#  echo "upgrading without xml"
#	"$pecl" upgrade --force
#fi
printf "\n" | "$pecl" install raphf
if [[ ! "$vernum" == 8.0 ]]; then
  echo "extension=raphf.so" >> "$phpini"
  printf "\n" | "$pecl" install propro
  echo "extension=propro.so" >> "$phpini"
fi

cd "$phpdir"/bin
ln -sT "$phpdir"/bin/php /usr/bin/"$version"
# Installing extensions via PECL (giving default values for each)
if [[ "$vernum" == 8.0 ]]; then
  printf "\n" | "$pecl" install memcache
fi
#echo "extension=memcache" >> "$phpini"
printf "\n" | "$pecl" install oauth
#echo "extension=oauth" >> "$phpini"
printf "\n" | "$pecl" install seaslog
#echo "extension=seaslog" >> "$phpini"
printf "\n" | "$pecl" install swoole
#echo "extension=swoole" >> "$phpini"

if [[ "$vernum" == 8.0 ]]; then
	printf "\n" | "$pecl" install pecl_http
#	echo "extension=http" >> "$phpini"
else
	printf "\n" | "$pecl" install pecl_http-3.2.4
#	echo "extension=http" >> "$phpini"
fi

if [[ ! "$vernum" == 8.0 ]]; then
#  echo "extension=memcache.so" >> "$phpini"
  echo "extension=oauth.so" >> "$phpini"
  echo "extension=seaslog.so" >> "$phpini"
  echo "extension=swoole.so" >> "$phpini"
	echo "extension=http.so" >> "$phpini"
fi

# Installing Xdebug without PECL
xdeb=xdebug-3.0.3
xdebdir="$phpdir"/"$xdeb"
extdir=$("$pecl" config-show | grep ext_dir | awk '{print $5}')
wget http://xdebug.org/files/"$xdeb".tgz -O /tmp/"$xdeb".tgz
tar -xvzf /tmp/"$xdeb".tgz -C "$phpdir"
cd "$xdebdir"
"$phpdir"/bin/phpize
./configure --with-php-config="$phpdir"/bin/php-config
make -j"$threads"
cp "$xdebdir"/modules/xdebug.so "$extdir"
echo "zend_extension=$extdir/xdebug.so" >> "$phpini"