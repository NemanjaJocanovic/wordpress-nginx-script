#!/bin/bash

#Update the System
sudo apt update && sudo apt upgrade -y

#Install dependencies
if ! command -v wget &> /dev/null; then
    echo "wget not found, installing..."
    sudo apt install wget -y
else
    echo "wget is already installed"
fi

if ! command -v tar &> /dev/null; then
    echo "tar not found, installing..."
    sudo apt install tar -y
else
    echo "tar is already installed"
fi

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

#Enable Nginx configuration
sudo ln -s /etc/nginx/sites-available/$IP.conf /etc/nginx/sites-enabled/

#Disable default Nginx configuration
sudo unlink /etc/nginx/sites-enabled/default

#Test Nginx configuration
sudo nginx -t

#Restart Nginx
sudo systemctl restart nginx

#Installing PHP extensions for WordPress
sudo apt install php8.1-common php8.1-mysql php8.1-xml php8.1-xmlrpc php8.1-curl php8.1-gd php8.1-imagick php8.1-cli php8.1-dev php8.1-imap php8.1-mbstring php8.1-opcache php8.1-soap php8.1-zip php8.1-intl -y

#User Input for the database 
read -p "Enter a name for the MySQL database: " DB_NAME
read -p "Enter a username for the MySQL user: " DB_USER
read -sp "Enter a password for the MySQL user: " DB_PASSWORD
echo ""

#Create a MySQL database
sudo mysql -e "CREATE DATABASE $DB_NAME;"
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Get the IP address of the instance
IP=$(curl -s http://checkip.amazonaws.com)

#Download latest WordPress package
wget https://wordpress.org/latest.tar.gz

#Extract the WordPress package
tar -zxf latest.tar.gz

#Copy WordPress files to the web root
sudo cp -r wordpress/* /var/www/$IP

#Setting ownership of the WordPress files
sudo chown -R www-data:www-data /var/www/$IP    

#Create a WordPress configuration file
sudo cp /var/www/$IP/wp-config-sample.php /var/www/$IP/wp-config.php

#Update the WordPress configuration file
sudo sed -i "s/database_name_here/$DB_NAME/g" /var/www/$IP/wp-config.php
sudo sed -i "s/username_here/$DB_USER/g" /var/www/$IP/wp-config.php
sudo sed -i "s/password_here/$DB_PASSWORD/g" /var/www/$IP/wp-config.php

# Download wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

# Make wp-cli executable
sudo chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Get user input for WordPress installation details
read -p "Enter the website title: " WP_TITLE
read -p "Enter the WordPress admin username: " WP_ADMIN_USER
read -p "Enter the WordPress admin email: " WP_ADMIN_EMAIL
read -sp "Enter the WordPress admin password: " WP_ADMIN_PASSWORD
echo ""

# Install WordPress using wp-cli
cd /var/www/$IP
sudo -u www-data wp core install --url="http://$IP" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_email="$WP_ADMIN_EMAIL" --admin_password="$WP_ADMIN_PASSWORD"