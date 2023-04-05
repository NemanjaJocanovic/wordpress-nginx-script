#!/bin/bash

#Update the System
sudo apt update && sudo apt upgrade -y

#Install Nginx
sudo apt install nginx -y
sudo systemctl enable nginx

#Install MySQL
sudo apt install mysql-server -y

#Install PHP
sudo apt install php-fpm php-mysql -y


