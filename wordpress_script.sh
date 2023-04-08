#!/bin/bash

valid_email() {
  local email
  local valid_email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  
  read -p "Your email address: " email
  while ! [[ "$email" =~ $valid_email_regex ]]; do
    echo >&2 "Invalid email address entered: $email"
    read -p "Please enter a valid email address: " email
  done
  echo "$email"
}

# Update the System
sudo apt update && sudo apt upgrade -y

# List of dependencies
dependencies=("wget" "tar" "curl" "sendmail" "ufw" "needrestart")

# Loop through the dependencies
for dep in "${dependencies[@]}"; do
    if ! command -v $dep &> /dev/null; then
        echo "$dep not found, installing..."
        sudo apt install $dep -y
    else
        echo "$dep is already installed"
    fi
done

# Setting needrestart to automatically restart services
sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

# Install Nginx
sudo apt install nginx -y

# Install UFW and allow Nginx traffic
sudo ufw allow 'Nginx Full'
echo "y" | sudo ufw enable

# Enable Nginx
sudo systemctl enable nginx

# Install MySQL
sudo apt install mysql-server -y

# Adding Ondrej's PPA
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install PHP
sudo apt install php8.2-fpm php-mysql -y

# Start and enable PHP-FPM
sudo systemctl start php8.2-fpm
sudo systemctl enable php8.2-fpm

# Validating the domain name
valid_domain_regex="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$"

read -p "Enter a domain name: " DOMAIN

while ! [[ "$DOMAIN" =~ $valid_domain_regex ]]; do
  echo "Invalid domain name entered: $DOMAIN"
  read -p "Enter a valid domain name: " DOMAIN
done

echo "The domain name '$DOMAIN' is valid."


# Configuring Nginx to use PHP Processor
sudo mkdir /var/www/$DOMAIN
sudo chown -R $USER:$USER /var/www/$DOMAIN

# Create a new Nginx configuration file
sudo touch /etc/nginx/sites-available/$DOMAIN.conf

# Nginx configuration file
cat <<EOF | sudo tee /etc/nginx/sites-available/$DOMAIN.conf
server {
    listen 80 default_server;
    server_name $DOMAIN;
    root /var/www/$DOMAIN;

    index index.html index.htm index.php;

    access_log /var/log/nginx/$DOMAIN-access.log;
    error_log /var/log/nginx/$DOMAIN-error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
     }

    location ~ /\.ht {
        deny all;
    }

}
EOF

# Enable Nginx configuration
sudo ln -s /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/

# Disable default Nginx configuration
sudo unlink /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Install Certbot and its Nginx plugin
sudo apt install certbot python3-certbot-nginx -y

# Certbot email address
echo "Please enter your email address for Certbot"
EMAIL_CERTBOT=$(valid_email)

# Request an SSL certificate
sudo certbot --nginx --agree-tos --redirect --non-interactive --email $EMAIL_CERTBOT -d $DOMAIN --test-cert
# Use the --test-cert flag to test the certificate, because of the limit of 5 certificates per week

# Restart and test Nginx 
sudo nginx -t
sudo systemctl restart nginx

# Cron job to renew the SSL certificate
echo "0 3 * * * root certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | sudo tee -a /etc/crontab > /dev/null

# Installing PHP extensions for WordPress
sudo apt install php8.2-common php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick php8.2-dev php8.2-mbstring php8.2-soap php8.2-zip php8.2-intl -y

# Install Fail2Ban
sudo apt install fail2ban -y

# Create a jail configuration file for WordPress
sudo touch /etc/fail2ban/jail.d/wordpress.conf

# Create fail2ban filter for WordPress authentication failures
sudo bash -c "cat > /etc/fail2ban/filter.d/wordpress.conf << EOL
[Definition]
failregex = ^<HOST> .* \"POST /wp-login.php
ignoreregex =
EOL"

# Configure the jail for authentication failures
cat <<EOF | sudo tee /etc/fail2ban/jail.d/wordpress.conf
[wordpress]
enabled = true
filter = wordpress
logpath = /var/log/nginx/$DOMAIN-access.log
maxretry = 5
findtime = 3600
bantime = 3600
action = iptables-multiport[name=WordpressFail, port="http,https", protocol=tcp]
EOF

# Create fail2ban filter for Nginx excessive request rates
sudo bash -c "cat > /etc/fail2ban/filter.d/nginx-req-limit.conf << EOL
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>
ignoreregex =
EOL"

# Create and configure fail2ban jail file for excessive request rates
sudo bash -c "cat > /etc/fail2ban/jail.local << EOL
[nginx-req-limit]
enabled  = true
filter   = nginx-req-limit
action   = iptables-multiport[name=ReqLimit, port=\"http,https\", protocol=tcp]
logpath  = /var/log/nginx/*error.log
findtime = 600
bantime  = 7200
maxretry = 10
EOL"

# Restart and Enable Fail2Ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# User Input for the database 
read -p "Enter a name for the MySQL database: " DB_NAME
read -p "Enter a username for the MySQL user: " DB_USER
read -sp "Enter a password for the MySQL user: " DB_PASSWORD
echo ""

# Create a MySQL database
sudo mysql -e "CREATE DATABASE $DB_NAME;"
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Download latest WordPress package
wget https://wordpress.org/latest.tar.gz

# Extract the WordPress package
tar -zxf latest.tar.gz

# Copy WordPress files to the web root
sudo cp -r wordpress/* /var/www/$DOMAIN

# Setting ownership of the WordPress files
sudo chown -R www-data:www-data /var/www/$DOMAIN    

# Create a WordPress configuration file
sudo cp /var/www/$DOMAIN/wp-config-sample.php /var/www/$DOMAIN/wp-config.php

# Update the WordPress configuration file
sudo sed -i "s/database_name_here/$DB_NAME/g" /var/www/$DOMAIN/wp-config.php
sudo sed -i "s/username_here/$DB_USER/g" /var/www/$DOMAIN/wp-config.php
sudo sed -i "s/password_here/$DB_PASSWORD/g" /var/www/$DOMAIN/wp-config.php

# Path to wp-config.php file
config_path="/var/www/$DOMAIN/wp-config.php"

# Remove existing salts from wp-config.php
sudo sed -i "/define( *'AUTH_KEY'/d" $config_path
sudo sed -i "/define( *'SECURE_AUTH_KEY'/d" $config_path
sudo sed -i "/define( *'LOGGED_IN_KEY'/d" $config_path
sudo sed -i "/define( *'NONCE_KEY'/d" $config_path
sudo sed -i "/define( *'AUTH_SALT'/d" $config_path
sudo sed -i "/define( *'SECURE_AUTH_SALT'/d" $config_path
sudo sed -i "/define( *'LOGGED_IN_SALT'/d" $config_path
sudo sed -i "/define( *'NONCE_SALT'/d" $config_path

# Fetch new salts and save them to a text file
curl https://api.wordpress.org/secret-key/1.1/salt/ > new_salts.txt

# Insert new salts into wp-config.php
sudo sed -i "51r new_salts.txt" $config_path

# Remove new_salts.txt 
rm new_salts.txt

# Download wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

# Make wp-cli executable
sudo chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Get user input for WordPress installation details
read -p "Enter the website title: " WP_TITLE
read -p "Enter the WordPress admin username: " WP_ADMIN_USER
read -sp "Enter the WordPress admin password: " WP_ADMIN_PASSWORD
echo ""

# Get user input for WordPress admin email address
echo "Please enter the WordPress admin email address"
WP_ADMIN_EMAIL=$(valid_email)

# Install WordPress using wp-cli
current_dir=$(pwd)
cd /var/www/$DOMAIN
sudo -u www-data wp core install --url="http://$DOMAIN" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_email="$WP_ADMIN_EMAIL" --admin_password="$WP_ADMIN_PASSWORD"

# Remove files
cd $current_dir
rm latest.tar.gz
rm -rf wordpress