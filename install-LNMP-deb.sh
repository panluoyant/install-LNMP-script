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
  apt-get install -y gcc g++ make wget tar cmake libpcre3-dev zlib1g-dev gcc-8 g++-8

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
