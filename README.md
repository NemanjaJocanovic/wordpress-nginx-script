 ## How to use the WordPress Installation and Configuration Bash Script ##

This script automates the installation and configuration process for a WordPress site on a Ubuntu 22.04 and 20.04 server. 
It takes care of installing and configuring Nginx, MySQL, PHP, Certbot, Fail2Ban, and WordPress itself, as well as setting up a secure SSL certificate for your domain.

Prerequisits:
* Before you begin, ensure that you have a valid domain name pointing to your server's IP address.
* After you boot up your Ubuntu server I recommend you run once `sudo apt update && sudo apt upgrade -y` and reboot your server with `sudo reboot now`. 
You can have some outdated kernel pop-ups during installation if you don't do this. they won't interrupt the installation, but will be annoying.

Instructions:

1. Download or pull the script

2. If you haven't downloaded or pulled the script directly to your server, upload it to the server with whatever you find fit.

3. Set script permissions:
SSH into your server and navigate to the directory where you uploaded or downloaded the script. Give the script executable permissions by running the following command:
`chmod +x wordpress_install.sh`

4. Run the script: Execute the script with root privileges by running this command : `sudo ./wordpress_install.sh`.
The script will prompt you to enter various information, such as your email address, domain name, MySQL database details, and WordPress installation details. 
Make sure to provide valid information when prompted.

5. Follow the Prompts:
* Enter your domain name when prompted. Make sure it's a valid domain name that points to your server's IP address.
* Enter your email address for Certbot when prompted.
* Enter the MySQL database, user, and password information when prompted.
* Enter the website title, WordPress admin username, password, and email address when prompted.

>The script will automatically install and configure all the required components and set up your WordPress site.

6. Access your WordPress site:
Once the script has finished running, open your web browser and navigate to your domain name (e.g., https://yourdomain.com). 
You should see your new WordPress site with the title you provided during the installation process.

7. Log in to the WordPress admin dashboard:
Navigate to https://yourdomain.com/wp-admin and enter the WordPress admin username and password you provided during the installation process. 
You can now manage your WordPress site from the admin dashboard.


By following these instructions, you have successfully installed and configured a WordPress site on your server using the provided script. 
If there is an error, it will be logged to `/var/log/wordpress_script.log`, and you will see the error message on the screen.
