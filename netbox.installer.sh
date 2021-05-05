#! /bin/bash
# Programming and idea by : Iman Homayouni
# Gitbub : https://github.com/iman-homayouni
# Email : homayouni.iman@Gmail.com
# Website : http://www.homayouni.info
# License : GPL v2.0
# Last update : 11-March-2021_19:53:05
# netbox.installer v1.0.1
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #
# SUCCESSFULLY TESTED IN UBUNTU 18.04 [BIONIC]
# SUCCESSFULLY TESTED IN UBUNTU 20.04 [FOCAL]
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# USAGE FUNCTION # ---------------------------------------------------------------------------------------------------------------------------------------- #
function usage {
    echo -e "$0 [SILENT MODE - DEFAULT USERNAME AND PASSWORD]"
    echo -e "$0 -f [ASK USERNAME AND PASSWORD]"
    echo -e "$0 -h [HELP USAGE]"
}
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CHECK INPUT # ------------------------------------------------------------------------------------------------------------------------------------------- #
if [ "$1" = "-h" ] ; then
    usage
    exit 0
fi
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CHECK OS RELEASE # -------------------------------------------------------------------------------------------------------------------------------------- #
release=$(lsb_release -sc)
if [ "$release" = "focal" ] ; then
    echo
elif [ "$release" = "bionic" ] ; then
    echo
else
    echo -e "[>] UBUNTU CODE NAME ITS NOT FOCAL OR BIONIC" && exit 1
fi
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# UPDATE AND UPGRADE SYSTEM # ----------------------------------------------------------------------------------------------------------------------------- #
apt-get update
apt-get -y dist-upgrade
apt -y autoremove
apt-get -f install
apt-get clean
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# INSTALL POSTGRESQL DATABASE # --------------------------------------------------------------------------------------------------------------------------- #
apt-get install -y git net-tools
apt-get install -y postgresql libpq-dev
apt-get install -y postgresql-contrib
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CREATE DATABASE # --------------------------------------------------------------------------------------------------------------------------------------- #
su - postgres -c "psql -c 'CREATE DATABASE netbox;'"
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# SET PASSWORD FOR USER NETBOX # -------------------------------------------------------------------------------------------------------------------------- #
clear

if [ -z "$1" ] ; then
    if [ -f databasepassword.txt ] ; then
        password=$(cat databasepassword.txt)
        if [ -z "$password" ] ; then
            touch databasepassword.txt
            password="$RANDOM$RANDOM"
            echo "$password" > databasepassword.txt
        fi
    else
        touch databasepassword.txt
        password="$RANDOM$RANDOM"
        echo "$password" > databasepassword.txt
    fi
else
    echo -en "[>] CREATE USER netbox WITH PASSWORD. ENTER YOUR PASSWORD : " ; read password
fi

echo "psql -c \"CREATE USER netbox WITH PASSWORD |$password|;\"" > /tmp/netbox.install.temp
sed -i "s/|/'/g" /tmp/netbox.install.temp
su - postgres < /tmp/netbox.install.temp
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# REMOVE TEMP FILE # -------------------------------------------------------------------------------------------------------------------------------------- #
rm -rf /tmp/netbox.install.temp &> /dev/null
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# SET PRIVILEGES FOR DB # --------------------------------------------------------------------------------------------------------------------------------- #
su - postgres -c "psql -c 'GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;'"
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# REMOVE OLD NETBOX DIRECTORY # --------------------------------------------------------------------------------------------------------------------------- #
rm -rf /opt/netbox/ &> /dev/null
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CLONE MAIN REPOSITORY IN SYSTEM # ----------------------------------------------------------------------------------------------------------------------- #
cd /opt/
git clone -b master https://github.com/digitalocean/netbox.git
[ ! -d netbox ] && echo -e "[>] CANNOT ACCESS '/opt/netbox': NO SUCH DIRECTORY" && exit 1
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CREATE SYMBOLIC LINK FROM PYTHON3 # --------------------------------------------------------------------------------------------------------------------- #
ln -s /usr/bin/python3 /usr/bin/python &> /dev/null
cd /opt/netbox/netbox/
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# GENERATE SECRET KEY # ----------------------------------------------------------------------------------------------------------------------------------- #
SECRET_KEY=$(./generate_secret_key.py)
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# COPY CONFIGURATION # ------------------------------------------------------------------------------------------------------------------------------------ #
cd netbox
cp configuration.example.py configuration.py
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CHANGE configuration.py FILE # -------------------------------------------------------------------------------------------------------------------------- #
line_number=$(cat configuration.py | grep -n 'ALLOWED_HOSTS' | grep -v '#' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'SECRET_KEY' | grep -v '#' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'Database name' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'PostgreSQL username' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'PostgreSQL password' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'Database server' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'Database port' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'Max database connection age' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py
sed -i "${line_number}d" configuration.py

line_number=$(cat configuration.py | grep -n 'DATABASE = {' | cut -d ':' -f 1)
sed -i "${line_number}d" configuration.py
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CHANGE configuration.py FILE # -------------------------------------------------------------------------------------------------------------------------- #
clear

if [ -z "$1" ] ; then
    server_ip=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
else
    echo -en "[>] ENTER YOU SERVER IP ADDRESS : " ; read server_ip
fi

echo "ALLOWED_HOSTS = [\"$server_ip\"]" > /tmp/netbox.install.temp
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CHANGE configuration.py FILE # -------------------------------------------------------------------------------------------------------------------------- #
cat /tmp/netbox.install.temp | tr '"' "'" > /tmp/netbox.install.temp2
cat /tmp/netbox.install.temp2 >> configuration.py

echo "DATABASE = {" >> configuration.py
echo "    'NAME': 'netbox', # Database name" >> configuration.py
echo "    'USER': 'netbox', # PostgreSQL username" >> configuration.py
echo "    \"PASSWORD\": \"$password\", # PostgreSQL password" > /tmp/netbox.install.temp

cat /tmp/netbox.install.temp | tr '"' "'" > /tmp/netbox.install.temp2
cat /tmp/netbox.install.temp2 >> configuration.py

echo "    'HOST': 'localhost', # Database server" >> configuration.py
echo "    'PORT': '', # Database port (leave blank for default)" >> configuration.py
echo "    'CONN_MAX_AGE': 300, # Max database connection age" >> configuration.py
echo "}" >> configuration.py
echo "SECRET_KEY = \"$SECRET_KEY\"" > /tmp/netbox.install.temp

cat /tmp/netbox.install.temp | tr '"' "'" > /tmp/netbox.install.temp2
cat /tmp/netbox.install.temp2 >> configuration.py

rm -rf /tmp/netbox.install.temp /tmp/netbox.install.temp2
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# INSTALL PIP3 PACKAGE IN SYSTEM # ------------------------------------------------------------------------------------------------------------------------ #
apt-get update
apt-get install -y python3-pip
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# INSTALL PYTHONS MODULES # ------------------------------------------------------------------------------------------------------------------------------- #
pip3 install -r /opt/netbox/requirements.txt
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# MIGRATE THE DATABASE # ---------------------------------------------------------------------------------------------------------------------------------- #
cd /opt/netbox/netbox/
python3 manage.py migrate
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CREATE SUPER USER IN NETBOX # --------------------------------------------------------------------------------------------------------------------------- #
if [ -z "$1" ] ; then
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@local.host', 'admin')" \
    | python manage.py shell 2> /dev/null
else

    for (( ;; )) ; do

        for (( ;; )) ; do
            # CLEAN UP TERMINAL # ------------------------------------------------------------------------------------------------------------------------- #
            clear
            # --------------------------------------------------------------------------------------------------------------------------------------------- #



            # PRINT QUESTION IN TERMINAL # ---------------------------------------------------------------------------------------------------------------- #
            echo -e "[>] ----------------------------------------------------------------------------------- [<]"
            echo -en "[>] Enter your netbox username [admin] : " ; read manage_username

            if [ -z "$manage_username" ] ; then
                echo "[>] username variables is empty"
                sleep 3
            else
                break
            fi
            # --------------------------------------------------------------------------------------------------------------------------------------------- #
        done



        for (( ;; )) ; do
            # PRINT QUESTION IN TERMINAL # ---------------------------------------------------------------------------------------------------------------- #
            echo -en "[>] Enter your netbox password [admin] : " ; read manage_password

            if [ -z "$manage_password" ] ; then
                echo "[>] password variables is empty"
                sleep 3
            else
                break
            fi
            # --------------------------------------------------------------------------------------------------------------------------------------------- #
        done



        for (( ;; )) ; do
            # PRINT QUESTION IN TERMINAL # ---------------------------------------------------------------------------------------------------------------- #
            echo -en "[>] Enter your netbox email address [admin@local.host] : " ; read manage_email

            if [ -z "$manage_email" ] ; then
                echo "[>] email variables is empty"
                sleep 3
            else
                break
            fi
            # --------------------------------------------------------------------------------------------------------------------------------------------- #
        done



        # CLEAN UP TERMINAL # ----------------------------------------------------------------------------------------------------------------------------- #
        clear
        # ------------------------------------------------------------------------------------------------------------------------------------------------- #



        # PRINT INFORMATION IN TERMINAL # ----------------------------------------------------------------------------------------------------------------- #
        echo -e "[>] ----------------------------------------------------------------------------------- [<]"
        echo -e "[>] Your netbox username : $manage_username"
        echo -e "[>] Your netbox password : $manage_password"
        echo -e "[>] Your netbox email address : $manage_email"
        echo -en "[>] IS THAT CORRECT ? [y/n] : " ; read q

        if [ "$q" = "y" ] ; then
            break
        fi
        # ------------------------------------------------------------------------------------------------------------------------------------------------- #
    done



    # PRINT SEPRATOR IN TERMINAL # ------------------------------------------------------------------------------------------------------------------------ #
    echo -e "[>] ----------------------------------------------------------------------------------- [<]"
    # ----------------------------------------------------------------------------------------------------------------------------------------------------- #



    # CREATE SUPER USER IN NETBOX # ----------------------------------------------------------------------------------------------------------------------- #
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser(\"$manage_username\", \"$manage_email\", \"$manage_password\")" \
    | python manage.py shell 2> /dev/null
    # ----------------------------------------------------------------------------------------------------------------------------------------------------- #

fi
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# COLLECT STATIC # ---------------------------------------------------------------------------------------------------------------------------------------- #
python3 manage.py collectstatic
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# INSTALL gunicorn MODULE USING PIP3 # -------------------------------------------------------------------------------------------------------------------- #
pip3 install gunicorn
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# GENERATE gunicorn_config CONFIGURATION FILE # ----------------------------------------------------------------------------------------------------------- #
cat << EOF > /opt/netbox/gunicorn_config.py
command = '/usr/local/bin/gunicorn'
pythonpath = '/opt/netbox/netbox'
bind = '$server_ip:8001'
workers = 3
user = 'www-data'
EOF
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# INSTALL supervisor PACKAGE IN SYSTEM USING APT # -------------------------------------------------------------------------------------------------------- #
apt-get update
apt-get -y install supervisor
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CREATE NETBOX CONFIGURATION FOR supervisor # ------------------------------------------------------------------------------------------------------------ #
cat << EOF > /etc/supervisor/conf.d/netbox.conf
[program:netbox]
command = gunicorn -c /opt/netbox/gunicorn_config.py netbox.wsgi
directory = /opt/netbox/netbox/
user = www-data
EOF
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# RESTART supervisor SERVICE # ---------------------------------------------------------------------------------------------------------------------------- #
systemctl restart supervisor
systemctl status supervisor
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# INSTALL NGINX WEB SERVER USING APT # -------------------------------------------------------------------------------------------------------------------- #
apt-get update
apt-get -y install nginx
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CREATE NETBOX CONFIGURATION FOR NGINX WEB SERVER # ------------------------------------------------------------------------------------------------------ #
cat << EOF > /etc/nginx/sites-available/netbox.conf
server {
    listen 80;
    server_name $server_ip;
    client_max_body_size 25m;

    location /static/ {
        alias /opt/netbox/netbox/static/;
    }

    location / {
        proxy_pass http://$server_ip:8001;
    }
}
EOF
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CREATE SYMBOLIC LINK FOR NGINX CONFIGURATION # ---------------------------------------------------------------------------------------------------------- #
ln -s /etc/nginx/sites-available/netbox.conf /etc/nginx/sites-enabled/ &> /dev/null
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# CHECK NGINX CONFIGURATION SYNTAX # ---------------------------------------------------------------------------------------------------------------------- #
nginx -t
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# RESTART NGINX SERVICER # -------------------------------------------------------------------------------------------------------------------------------- #
systemctl restart nginx
systemctl status nginx
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# MOVE DATABASE PASSWORD FILE TO /OPT/NETBOX #
mv databasepassword.txt /opt/netbox/
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# PRINT RESULT IN TERMINAL # ------------------------------------------------------------------------------------------------------------------------------ #
reset
echo -e "\e[92m[>] ----------------------------------------------------------------- [<]"
echo -e "[>] DATABASE USERNAME IS : netbox"
echo -e "[>] DATABASE PASSWORD IS : $password"
echo -e "[>] DATABASE PASSWORD FILE AVAILABLE IN /opt/netbox/databasepassword.txt"
echo -e "[>] ----------------------------------------------------------------- [<]"
echo -e "[>] NETBOX PANEL USERNAME IS : admin"
echo -e "[>] NETBOX PANEL PASSWORD IS : admin"
echo -e "[>] NETBOX PANEL EMAIL IS : admin@local.host"
echo -e "[>] NETBOX PANEL URL : http://$server_ip/"
echo -e "[>] ----------------------------------------------------------------- [<]\e[0m"
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #
