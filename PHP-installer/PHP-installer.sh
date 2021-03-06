#!/bin/bash
# PHP-installer
# Please read the README located in this directory before use.
# Created by: George Sims

# exit script on error
set -e

avail_versions=(8.0 7.4 7.3)
vernum=$1
threads=$2
version=php-"$vernum"
gitversion="$version".0
phpdir=/opt/"$version"

# Function to install a PHP extension
# param 1: extension name
# param 2: version number (must include '-', i.e $ ext_install pecl_http -4.3.2)
ext_install() {
  printf "\n" | "$pecl" install $1$2
  # pecl_http is downloaded but needs http.so in php.ini not pecl_http.so
  # bad solution but could be improved with more time
  if [[ $1 == pecl_http ]]; then
    echo "==> 'Adding extension=$1.so' to $phpini"
    echo "extension=http.so" >> "$phpini"
  else
    echo "==> 'Adding extension=$1.so' to $phpini"
    echo "extension=$1.so" >> "$phpini"
  fi
}

# Check whether the given version number is included in the avail_versions array
# https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
if [[ ! " ${avail_versions[@]} " =~ " ${vernum} " ]]; then
	echo "Please choose one of the avaliable versions: 8.0, 7.4 or 7.3"
	exit
fi
if [[ threads > $(nproc) ]]; then
  echo "Too many threads, please run with MAX THREADS <= $(nproc))"
  exit
fi

# --- Installing PHP from source ---
# Download the tarball from Github into /tmp
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
if [[ -f "/tmp/$gitversion.tar.gz" ]]; then
  while true; do
    read -p "/tmp/$gitversion.tar.gz already exists, do you wish to use it? Saying no will overwrite the old version [y/n]: " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) wget https://github.com/php/php-src/archive/"$gitversion".tar.gz -O /tmp/"$gitversion".tar.gz; break;;
        * ) echo "Please answer yes or no.";;
    esac
  done
  else
    wget https://github.com/php/php-src/archive/"$gitversion".tar.gz -O /tmp/"$gitversion".tar.gz
fi
if [[ -d "/opt/php-src-$gitversion" ]]; then
  echo "/opt/php-src-$gitversion already exists, please remove it and run this again"
  exit
  elif [[ -d "$phpdir" ]]; then
  echo "$phpdir already exists, please remove it and run this again"
  exit
fi
# Untar it into /opt
tar -xf /tmp/"$gitversion".tar.gz -C /opt
# Github forces the untarred file to start with 'php-src', this changes the dir name to php-<ver>
mv /opt/php-src-"$gitversion" "$phpdir"
cd "$phpdir"
echo "==> Starting build of $phpdir"
./buildconf --force
# Install PHP into the /opt/php-<ver> directory with pear working out of the box. Pear depends on openssl
./configure --prefix="$phpdir"  \
	--with-openssl 		\
	--with-pear
make -j"$threads"
make install
echo "==> Build complete"

# --- Configuring PEAR/PECL ---
echo "==> Setting up PEAR/PECL for $phpdir"
phpini="$phpdir"/lib/php.ini
# Copy 'production' .ini file as the PHP.ini
cp "$phpdir"/php.ini-production "$phpini"
pecl="$phpdir"/bin/pecl
pear="$phpdir"/bin/pear
"$pear" config-set cache_dir /tmp/pear-"$version"/cache
"$pear" config-set temp_dir /tmp/pear-"$version"/temp
"$pear" config-set download_dir /tmp/pear-"$version"/download
# Link the php-<ver>'s .ini file to its pecl, to allow installation of extensions into this php only
"$pecl" config-set php_ini "$phpini"
"$pecl" update-channels

# --- Installing extensions ---
echo "==> Installing extensions for $phpdir"
ext_install raphf
if [[ ! "$vernum" == 8.0 ]]; then
  # Dependency not required in 8.0
  ext_install propro
  # Different versions of pecl_http are required for 8.0 compared to 7.3 and 7.4
	ext_install pecl_http -3.2.4
else
  # memcache has compatibility issues <PHP-8.0 I believe with the system installed version
  ext_install memcache
  ext_install pecl_http
fi
ext_install oauth
ext_install seaslog
ext_install swoole

# --- Installing Xdebug without PECL ---
echo "==> Installing Xdebug from source"
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
echo "==> 'Adding zend_extension=$extdir/xdebug.so' to $phpini"
echo "zend_extension=$extdir/xdebug.so" >> "$phpini"

# --- Make copies of config files for 2nd script to check ---
echo "==> Creating copies of all config files"
configdir="$phpdir"/.config
# Create copy of php.ini file to allow the next script to check for changes
mkdir "$phpdir"/.config
cp "$phpini" "$phpdir"/.config/php.ini_backup
# Create copies of all std extensions into /opt/php-<ver>/.config
for dir in $phpdir/ext/*/; do
  extension=$(basename "$dir")
  mkdir -p "$configdir"/"$extension"
  # Check if config exists before trying to copy, some extensions don't have both .m4 and .w32
  if [[ -f "$dir"/config.m4 ]]; then
    cp "$dir"/config.m4 "$configdir"/"$extension"
  fi
  if [[ -f "$dir"/config.w32 ]]; then
    cp "$dir"/config.w32 "$configdir"/"$extension"
  fi
done
cd "$phpdir"/bin
# Create symlink to the PHP executable named php-<ver>
ln -sT "$phpdir"/bin/php /usr/bin/"$version"
echo "==> $version binary can now be used, e.g. '$ $version -v'. Please use PHP-checker script beforehand"
echo "==> Install complete"
