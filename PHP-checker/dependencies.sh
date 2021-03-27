yum update -y && \
yum install mysql-devel \
php-devel \
libcurl-devel \
rhash-devel \
autoconf \
libtool \
bison \
libxml2-devel \
bzip2-devel \
libcurl-devel \
libpng-devel \
libicu-devel \
gcc-c++ \
libmcrypt-devel \
libwebp-devel \
libjpeg-devel \
openssl-devel \
mysql-devel \
sqlite-devel \
libxslt-devel -y && \
wget http://mirror.centos.org/centos/8/PowerTools/x86_64/os/Packages/re2c-0.14.3-2.el8.x86_64.rpm -P /tmp && \
rpm -Uvh /tmp/re2c-0.14.3-2.el8.x86_64.rpm