	#!/bin/bash
	
	echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
	echo "LANG=en_US.utf-8" >> /etc/environment
	echo "LC_ALL=en_US.utf-8" >> /etc/environment
	service sshd restart
	hostnamectl set-hostname frontend
	amazon-linux-extras install php7.4 
	yum install httpd -y
	systemctl restart httpd
	systemctl enable httpd
	wget https://wordpress.org/latest.zip
	unzip latest.zip
	cp -rf wordpress/* /var/www/html/
	mv /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
	chown -R apache:apache /var/www/html/*
	cd  /var/www/html/
	sed -i 's/database_name_here/blog/g' wp-config.php
    sed -i 's/username_here/bloguser/g' wp-config.php
	sed -i 's/password_here/bloguser123/g' wp-config.php
	sed -i 's/localhost/db.pratheeshsatheeshkumar.local/g' wp-config.php
