#!/bin/bash

set -e

# --- Installing PHP from source ---
avail_versions=(8.0 7.4 7.3)
vernum=$1
threads=$2
# Check whether the given version number is included in the avail_versions array
if [[ ! " ${avail_versions[@]} " =~ " ${vernum} " ]]; then
	echo "Please choose one of the avaliable versions: 8.0, 7.4 or 7.3"
	exit
fi
version=php-"$vernum"
gitversion="$version".0
phpdir=/opt/"$version"

# Download the tarball from Github into /tmp
wget https://github.com/php/php-src/archive/"$gitversion".tar.gz -O /tmp/"$gitversion".tar.gz
# Untar it into /opt
tar -xf /tmp/"$gitversion".tar.gz -C /opt
# Github forces the untarred file to start with 'php-src', this changes the dir name to php-<ver>
mv /opt/php-src-"$gitversion" "$phpdir"
cd "$phpdir"
./buildconf --force
# Install PHP into the /opt/php-<ver> directory with pear working out of the box. Pear depends on openssl
./configure --prefix="$phpdir"  \
	--with-openssl 		\
	--with-pear
make -j"$threads"
# make test --don't forget this
make install

# --- Configuring PEAR/PECL ---
phpini="$phpdir"/lib/php.ini
# Copy 'production' .ini file as the PHP.ini
cp "$phpdir"/php.ini-production "$phpini"
pecl="$phpdir"/bin/pecl
# Attempted to change pear cache manually, but was unsuccessful
#"$pecl" config-set cache_dir /tmp/pear-"$version"/cache
# Link the php-<ver>'s .ini file to its pecl, to allow installation of extensions into this php only
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

# --- Installing extensions ---
printf "\n" | "$pecl" install raphf
# Using PHP 8.0 does not require the user to write "extension=<extension-name>" to the php.ini
if [[ ! "$vernum" == 8.0 ]]; then
  echo "extension=raphf.so" >> "$phpini"
  # Dependency not required in 8.0
  printf "\n" | "$pecl" install propro
  echo "extension=propro.so" >> "$phpini"
fi
cd "$phpdir"/bin
# Create symlink to the PHP executable named php-<ver>
ln -sT "$phpdir"/bin/php /usr/bin/"$version"
if [[ "$vernum" == 8.0 ]]; then
  # Unfortunately memcache could not be installed sucessfully on < 8.0 due to dependency problems (with memcache-devel)
  printf "\n" | "$pecl" install memcache
fi
# printf "\n" | <pecl install> allows to give default values to extensions. This can be improved depending on user needs
printf "\n" | "$pecl" install oauth
printf "\n" | "$pecl" install seaslog
printf "\n" | "$pecl" install swoole

# Different versions of pecl_http are required for 8.0 compared to 7.3 and 7.4
if [[ "$vernum" == 8.0 ]]; then
	printf "\n" | "$pecl" install pecl_http
else
	printf "\n" | "$pecl" install pecl_http-3.2.4
fi

if [[ ! "$vernum" == 8.0 ]]; then
#  echo "extension=memcache.so" >> "$phpini"
  echo "extension=oauth.so" >> "$phpini"
  echo "extension=seaslog.so" >> "$phpini"
  echo "extension=swoole.so" >> "$phpini"
	echo "extension=http.so" >> "$phpini"
fi

# --- Installing Xdebug without PECL ---
xdeb=xdebug-3.0.3
xdebdir="$phpdir"/"$xdeb"
# Store the long unique path name to the extensions as a variable (e.g. /opt/php-ver/lib/php/extensions/zts-nodebug-2003002/)
extdir=$("$pecl" config-show | grep ext_dir | awk '{print $5}')
# Download tarball from xdebug directly
wget http://xdebug.org/files/"$xdeb".tgz -O /tmp/"$xdeb".tgz
# Untar into the corresponding php-<ver> directory
tar -xvzf /tmp/"$xdeb".tgz -C "$phpdir"
cd "$xdebdir"
# Use the correct php-<ver>'s phpize
"$phpdir"/bin/phpize
# Configure for use only with this php-<ver>
./configure --with-php-config="$phpdir"/bin/php-config
make -j"$threads"
# Copy the module into the extensions dir for this php-<ver>
cp "$xdebdir"/modules/xdebug.so "$extdir"
# Manually write this to the php.ini file
echo "zend_extension=$extdir/xdebug.so" >> "$phpini"