#!/bin/bash

vernum=$1
php=php-"$vernum"
testfile=/opt/"$php"/run-tests.php
exttests=/opt/"$php"/lib/php/test
logfile=/tmp/php-checker.log
# All stdout and stderr go to logfile, but can use fd 3 to output to terminal directly
# https://stackoverflow.com/questions/18460186/writing-outputs-to-log-file-and-console
exec 3>&1 1>>"$logfile" 2>&1

# Function for checking whether a PEAR extension has been installed and is loaded for this
# PHP version. It does this by using the given PHP version, and executing it with the
# -m flag, which lists loaded extensions, grep's return value is then used to confirm the
# extension is visible or not
ext_loaded() {
  tmp=$("$php" -m | grep $1)
  return $?
}

# Function for running test(s) for particular PEAR extension. -P flag uses executed PHP version
# to run them.
run_tests() {
  "$php" "$testfile" -P "$exttests"/"$1"/tests
  return $?
}

# --- Check php config file for changes ---
changed=$(diff /opt/php-"$vernum"/lib/php.ini /opt/php-"$vernum"/.config/php.ini_backup)
phpini=$?
if [[ phpini == 1 ]]; then
  echo "PHP config has been changed" 1>&3
else
  echo "PHP config is the same" 1>&3
fi

# --- Check extensions are loaded and functional ---
xdeb_ld=$(ext_loaded Xdebug)
http_ld=$(ext_loaded http)
oauth_ld=$(ext_loaded OAuth)
seaslog_ld=$(ext_loaded SeasLog)
swoole_ld=$(ext_loaded swoole)
if [[ "$vernum" == 8.0 ]]; then
  memche=$(ext_loaded memcache)
fi

# --- Run tests ---
php_tst=$("$php" "$testfile" -P /opt/"$php"/tests/basic)
echo $?
exit
oauth_tst=$(run_tests oauth)
if [[ oauth == 1 ]]; then
  echo "oauth tests failed" 1>&3
else
  echo "oauth tests passed" 1>&3
fi