#!/bin/bash
# PHP-checker
# Please read the README located in this directory before use.
# Created by: George Sims

avail_versions=(8.0 7.4 7.3)
vernum=$1
loop=$2
runexts=$3
# Check whether the given version number is included in the avail_versions array
# https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
if [[ ! " ${avail_versions[@]} " =~ " ${vernum} " ]]; then
	echo "Please choose one of the avaliable versions: 8.0, 7.4 or 7.3"
	exit
fi
# If no user input don't loop
if [[ -z "$loop" ]]; then
  loop=false
else
  loop=true
fi
if [[ -z "$runexts" ]]; then
  runexts=false
else
  runexts=true
fi
php=php-"$vernum"
phpdir=/opt/"$php"
configdir="$phpdir"/.config
testfile="$phpdir"/run-tests.php
exttests="$phpdir"/lib/php/test
logfile=/tmp/php-checker.log

# All stdout and stderr go to logfile, but can use fd 3 to output to terminal directly.
# This allows users to check why a command failed in the log file, whilst keeping this script's
# output uniform for monitoring applications to read
# https://stackoverflow.com/questions/18460186/writing-outputs-to-log-file-and-console
exec 3>&1 1>>"$logfile" 2>&1

# Function to echo output to stdout instead of the log file, rather than writing echo <string> 1>&3
echo_stdout() {
  echo $1 1>&3
}

# Function for checking whether a PEAR extension has been installed and is loaded for this
# PHP version. It does this by using the given PHP version, and executing it with the
# -m flag, which lists loaded extensions, grep's return value is then used to confirm the
# extension is visible or not. This has the same result as running PHP code to check if the extension
# is accessible, and is more readable
# param 1: extension name
# return 1: extension not loaded
#        0: extension loaded
ext_loaded() {
  "$php" -m | grep $1
  echo_stdout "$1_extension_loaded: $?"
}

# Function to check for a working PHP by running the tests located in the tests/basic directory.
# These tests are pre-defined and are the best way to check if there are any errors with the
# install. A user should consult the logfile if they wish to debug/check why a result is 1
# return 1: 1+ failed test(s) (and thus the log file should be checked for debugging)
#        0: test(s) passed
run_php_test() {
  "$php" "$testfile" -P "$phpdir"/tests/basic
  echo_stdout "php_basic_tests: $?"
}

# Function for running test(s) for particular PEAR extension. -P flag uses executed PHP version.
# Like the PHP tests, these tests are also pre-defined and the best indicator for errors.
# to run them
# param 1: extension name
# return 1: test(s) failed
#        0: test(s) passed
run_tests() {
  "$php" "$testfile" -P "$exttests"/"$1"/tests
  echo_stdout "$1_extension_tests: $?"
}

# Compares an extension's active config files in the /ext/<extension/ dir to check if they
# are the same as when the PHP-installer script finished (stored in the .config) directory
# param 1: location of extension's active config files
# param 2: extension name
# return 1: files are not the same/have been modified since install or do not exist (check log)
#        0: files match/have not been modified
check_configs() {
  diff "$1"/config.m4 "$configdir"/"$2"/config.m4
  m4=$?
  diff "$1"/config.w32 "$configdir"/"$2"/config.w32
  w32=$?
  if [[ "$m4" == 0 && "$w32" == 0 ]]; then
    echo_stdout "$2_config: 0"
  else
    echo_stdout "$2_config: 1"
  fi
  return $?
}

while :; do
  endtime=$(date -ud "1 minute" +%s)

  # --- Check php config file for changes ---
  diff "$phpdir"/lib/php.ini "$configdir"/php.ini_backup
  echo_stdout "phpini_config: $?"

  # --- Check extensions are loaded and functional ---
  # also shows php is functional without running tests
  ext_loaded Xdebug
  ext_loaded http
  ext_loaded OAuth
  ext_loaded SeasLog
  ext_loaded swoole
  if [[ "$vernum" == 8.0 ]]; then
    ext_loaded memcache
  fi

  # --- Check common extension's config files for changes ---
  for dir in $phpdir/ext/*/; do
    # get extension name from path
    extension=$(basename "$dir")
    check_configs "$dir" "$extension"
  done

  # --- Run tests (if -e flag given) ---
  if [[ "$runexts" = true ]]; then
    run_php_test
    run_tests oauth
    run_tests pecl_http
    run_tests seaslog
    run_tests swoole
    if [[ "$vernum" == 8.0 ]]; then
      run_tests memcache
    fi
  fi
  # If no loop flag was specified, exit while loop
  if [[ "$loop" = false ]]; then
    break
  fi

  # I understand that this is not the 'exact' count of 1 minute considering the
  # function definitions etc before the while loop began, but this was the simplest
  # solution under the time constraints. Also keeping the loop at one minute avoids
  # hogging the CPU, if no more than one set of values per minute are needed.
  # https://www.golinuxcloud.com/run-while-loop-until-specific-time-shell-bash/
  while [[ $(date -u +%s) < $endtime ]]; do
    sleep 1
  done
done