	#!/bin/bash
	
	echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
	echo "LANG=en_US.utf-8" >> /etc/environment
	echo "LC_ALL=en_US.utf-8" >> /etc/environment
	service sshd restart
	hostnamectl set-hostname backend
	amazon-linux-extras install php7.4 -y
	rm -rf /var/lib/mysql/*
	yum remove mysql -y
    yum install httpd mariadb-server -y
	systemctl restart mariadb.service
    systemctl enable mariadb.service
    mysqladmin -u root password 'mysql123'
	mysql -u root -pmysql123 -e "create database blog;"
	mysql -u root -pmysql123 -e "create user 'bloguser'@'%' identified by 'bloguser123';"
	mysql -u root -pmysql123 -e "grant all privileges on blog.* to 'bloguser'@'%'"
	mysql -u root -pmysql123 -e "flush privileges"

