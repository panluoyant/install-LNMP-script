#!/bin/bash

# 检查是否为 root 用户
if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1;31m错误：请以 root 权限执行此脚本！\e[0m"
    exit 1
fi

# 用户选择软件版本
declare -a NGINX_VERSIONS=("1.24.0" "1.23.0" "1.22.0")
declare -a PHP_VERSIONS=("8.1.0" "8.0.0" "7.4.0")
declare -a MYSQL_VERSIONS=("8.0.28" "5.7.35" "5.6.51")

echo "可用的 Nginx 版本:"
for i in "${!NGINX_VERSIONS[@]}"; do
  echo "$((i+1)). ${NGINX_VERSIONS[$i]}"
done
read -p "请选择一个版本 (1-${#NGINX_VERSIONS[@]}), 0 退出: " NGINX_CHOICE
if [[ "$NGINX_CHOICE" -eq 0 ]]; then exit 0; fi
NGINX_VERSION=${NGINX_VERSIONS[$NGINX_CHOICE-1]}

echo "可用的 PHP 版本:"
for i in "${!PHP_VERSIONS[@]}"; do
  echo "$((i+1)). ${PHP_VERSIONS[$i]}"
done
read -p "请选择一个版本 (1-${#PHP_VERSIONS[@]}), 0 退出: " PHP_CHOICE
if [[ "$PHP_CHOICE" -eq 0 ]]; then exit 0; fi
PHP_VERSION=${PHP_VERSIONS[$PHP_CHOICE-1]}

echo "可用的 MySQL 版本:"
for i in "${!MYSQL_VERSIONS[@]}"; do
  echo "$((i+1)). ${MYSQL_VERSIONS[$i]}"
done
read -p "请选择一个版本 (1-${#MYSQL_VERSIONS[@]}), 0 退出: " MYSQL_CHOICE
if [[ "$MYSQL_CHOICE" -eq 0 ]]; then exit 0; fi
MYSQL_VERSION=${MYSQL_VERSIONS[$MYSQL_CHOICE-1]}

# 创建临时目录
echo -e "\e[1;34m创建临时目录\e[0m"
mkdir -p ~/source
cd ~/source

# 自动安装编译依赖
echo -e "\e[1;34m安装编译依赖\e[0m"
yum -y install gcc gcc-c++ make wget tar cmake pcre pcre-devel zlib-devel
#mysql的依赖
yum -y install gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-binutils gcc-toolset-12-annobin-annocheck gcc-toolset-12-annobin-plugin-gcc
#安装GMP
wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.bz2
tar -xvf gmp-6.1.2.tar.bz2
cd gmp-6.1.2
./configure --prefix=/usr/local
make
sudo make install
make check
cd ..
#安装MPFR
#wget https://www.mpfr.org/mpfr-current/mpfr-4.2.1.tar.gz
wget https://mirrors.huaweicloud.com/gnu/mpfr/mpfr-4.2.1.tar.gz
tar -zxvf mpfr-4.2.1.tar.gz
cd mpfr-4.2.1
./configure --prefix=/usr/local --with-gmp=/usr/local
make
sudo make install
cd ..
#安装MPC
wget https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz 
tar -zxvf mpc-1.3.1.tar.gz
cd mpc-1.3.1
./configure --prefix=/usr/local --with-gmp=/usr/local --with-mpfr=/usr/local
make
sudo make install
cd ..
#刷新动态库
sudo sh -c "echo '/usr/local/lib' > /etc/ld.so.conf.d/local_libs.conf"
sudo ldconfig

#安装gcc12
sudo yum install -y wget tar gcc gcc-c++ make gmp-devel mpfr-devel libmpc-devel
cd /opt
#wget http://ftp.gnu.org/gnu/gcc/gcc-12.3.0/gcc-12.3.0.tar.gz
wget https://mirrors.huaweicloud.com/gnu/gcc/gcc-12.3.0/gcc-12.3.0.tar.gz
tar -zxvf gcc-12.3.0.tar.gz
cd gcc-12.3.0
mkdir build
cd build
../configure --prefix=/usr/local/gcc-12 --enable-languages=c,c++  --disable-multilib
make -j$(nproc -all)
sudo make install
export PATH=/usr/local/gcc-12/bin:$PATH
source ~/.bashrc

# 检查并备份 Nginx
if [ -d "/usr/local/nginx" ]; then
    echo -e "\e[1;34m备份现有的 Nginx\e[0m"
    mv /usr/local/nginx /usr/local/nginx.backup.$(date +%F-%T)
fi

# 下载 Nginx 源代码
echo -e "\e[1;34m下载 Nginx 源代码\e[0m"
wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
tar -zxvf nginx-$NGINX_VERSION.tar.gz
cd nginx-$NGINX_VERSION

# 编译并安装 Nginx
echo -e "\e[1;34m编译并安装 Nginx\e[0m"
./configure
make
sudo make install

# 创建软链接
ln -sf /usr/local/nginx/sbin/nginx /usr/bin/nginx

# 创建 Nginx 服务文件并设置开机自启
cat <<EOF > /etc/systemd/system/nginx.service
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s quit
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nginx.service
systemctl start nginx.service

# 返回到临时目录
cd ~/source

# 检查并备份 PHP
if [ -d "/usr/local/bin/php" ]; then
    echo -e "\e[1;34m备份现有的 PHP\e[0m"
    mv /usr/local/bin/php /usr/local/bin/php.backup.$(date +%F-%T)
fi

# 下载 PHP 源代码
echo -e "\e[1;34m下载 PHP 源代码\e[0m"
wget https://www.php.net/distributions/php-$PHP_VERSION.tar.gz
tar -zxvf php-$PHP_VERSION.tar.gz
cd php-$PHP_VERSION

# 编译并安装 PHP
echo -e "\e[1;34m编译并安装 PHP\e[0m"
./configure
make
sudo make install

# 创建软链接
ln -sf /usr/local/bin/php /usr/bin/php

# 返回到临时目录
cd ~/source

# 检查并备份 MySQL
if [ -d "/usr/local/mysql" ]; then
    echo -e "\e[1;34m备份现有的 MySQL\e[0m"
    mv /usr/local/mysql /usr/local/mysql.backup.$(date +%F-%T)
fi

# 下载 MySQL 源代码
echo -e "\e[1;34m下载 MySQL 源代码\e[0m"
wget https://dev.mysql.com/get/Downloads/MySQL-$MYSQL_VERSION/mysql-$MYSQL_VERSION.tar.gz
tar -zxvf mysql-$MYSQL_VERSION.tar.gz
cd mysql-$MYSQL_VERSION

# 编译并安装 MySQL
echo -e "\e[1;34m编译并安装 MySQL\e[0m"
cmake .
make
sudo make install

# 初始化 MySQL 数据库并设置初始密码
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
/usr/local/mysql/bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data
echo "MySQL root 初始密码: $MYSQL_ROOT_PASSWORD"

# 创建 MySQL 服务文件并设置开机自启
cat <<EOF > /etc/systemd/system/mysql.service
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/mysql/bin/mysqld --user=mysql
ExecStop=/usr/local/mysql/bin/mysqladmin -u root -p shutdown
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mysql.service
systemctl start mysql.service

# 创建软链接
ln -sf /usr/local/mysql/bin/mysql /usr/bin/mysql

# 清理临时目录
echo -e "\e[1;34m清理临时目录\e[0m"
cd ~
rm -rf ~/source

echo -e "\e[1;32mNginx, PHP, 和 MySQL 已成功从源代码编译并安装完成！\e[0m"
echo "安装位置：Nginx -> /usr/local/nginx, PHP -> /usr/local/bin, MySQL -> /usr/local/mysql"
echo "MySQL 初始密码：$MYSQL_ROOT_PASSWORD"
