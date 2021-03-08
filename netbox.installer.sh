#! /bin/bash



# USAGE FUNCTION # ---------------------------------------------------------------------------------------------------------------------------------------- #
function usage {
    echo -e "$0 -s [SILENT MODE]"
    echo -e "$0 [NORMAL INSTALLATION]"
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
[ "$release" != "focal" ] && echo -e "[>] UBUNTU CODE NAME ITS NOT FOCAL" && exit 1
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

if [ "$1" = "-s" ] ; then
    password="$RANDOM$RANDOM"
    touch $password.databasepassword
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
ln -s /usr/bin/python3 /usr/bin/python &> /dev/null
cd /opt/netbox/netbox/
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #



# GENERATE SECRET KEY # ----------------------------------------------------------------------------------------------------------------------------------- #
SECRET_KEY=$(./generate_secret_key.py)
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #

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

if [ "$1" = "-s" ] ; then
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
if [ "$1" = "-s" ] ; then
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@local.host', 'admin')" \
    | python manage.py shell
else
    clear

    echo -e "[>] ----------------------------------------------------------------- [<]"
    echo -e "[>] Example:"
    echo -e "Username (leave blank to use 'root'): netboxadmin"
    echo -e "Email address: hitjethva@gmail.com"
    echo -e "Password: "
    echo -e "Password (again): "
    echo -e "Superuser created successfully."
    echo -e "[>] ----------------------------------------------------------------- [<]"
    python3 manage.py createsuperuser
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



# PRINT RESULT IN TERMINAL # ------------------------------------------------------------------------------------------------------------------------------ #
reset
echo -e "\e[92m[>] ----------------------------------------------------------------- [<]"
echo -e "[>] DATABASE USERNAME IS : netbox"
echo -e "[>] DATABASE PASSWORD IS : $password"
echo -e "[>] DATABASE IS AVAILABLE IN $password.databasepassword"
echo -e "[>] ----------------------------------------------------------------- [<]"
if [ "$1" = "-s" ] ; then
    echo -e "[>] NETBOX PANEL USERNAME IS : admin"
    echo -e "[>] NETBOX PANEL PASSWORD IS : admin"
    echo -e "[>] NETBOX PANEL EMAIL IS : admin@local.host"
fi
echo -e "[>] NETBOX PANEL URL : http://$server_ip/"
echo -e "[>] ----------------------------------------------------------------- [<]\e[0m"
# --------------------------------------------------------------------------------------------------------------------------------------------------------- #
