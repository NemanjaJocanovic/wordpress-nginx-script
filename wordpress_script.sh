#!/bin/bash

#Update the System
sudo apt update && sudo apt upgrade -y

#Install Nginx
sudo apt install nginx -y
sudo systemctl enable nginx

#Install MySQL
sudo apt install mysql-server -y

#Install PHP
sudo apt install php8.1-fpm php-mysql -y

# Get the IP address of the instance
IP=$(curl -s http://checkip.amazonaws.com)

#Configuring Nginx to use PHP Processor
sudo mkdir /var/www/$IP
sudo chown -R $USER:$USER /var/www/$IP

# Create a new Nginx configuration file
sudo touch /etc/nginx/sites-available/$IP.conf

# Nginx configuration file
# Nginx configuration file
cat <<EOF | sudo tee /etc/nginx/sites-available/$IP.conf
server {
    listen 80 default_server;
    server_name $IP;
    root /var/www/$IP;

    index index.html index.htm index.php;

    access_log /var/log/nginx/$IP-access.log;
    error_log /var/log/nginx/$IP-error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
     }

    location ~ /\.ht {
        deny all;
    }

}
EOF

#Files for testing
echo "<?php echo 'Hello, world!'; ?>" | sudo tee /var/www/$IP/index.php
echo "<?php phpinfo(); ?>" | sudo tee /var/www/$IP/phpinfo.php

#Enable Nginx configuration
sudo ln -s /etc/nginx/sites-available/$IP.conf /etc/nginx/sites-enabled/

#Disable default Nginx configuration
sudo unlink /etc/nginx/sites-enabled/default

#Test Nginx configuration
sudo nginx -t

#Restart Nginx
sudo systemctl restart nginx