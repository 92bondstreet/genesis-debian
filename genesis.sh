#!/bin/bash

## Custom echo
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'

## Color-echo.
#  Reset text attributes to normal + without clearing screen.
alias Reset="tput sgr0"
# arg $1 = message
# arg $2 = Color
cecho() {
  echo "${2}${1}"
  Reset # Reset to normal.
  return
}

# Display header
header() {
  cecho "------------------------------------------------------------------------------" $yellow
  cecho "$*" $yellow
  cecho "------------------------------------------------------------------------------" $yellow

}

# Who are you?
if [ "$(id -u)" != "0" ]; then
  cecho "Genesis is for ROOT" $red
  cecho "❯ su" $red
  exit 1
fi

DATABASE=false
FIREWALL=false
NGINX=false
SHIELD=false
TERMINAL=false
VAGRANT=false

cd $HOME
PWD="$(pwd)"

while [ $# -gt 0 ]
do
    case "$1" in
        --database)
            DATABASE=true
            ;;
        --firewall)
            FIREWALL=true
            ;;
        --nginx)
            NGINX=true
            ;;
        --shield)
            SHIELD=true
            ;;
        --terminal)
            TERMINAL=true
            ;;
        --vagrant)
            VAGRANT=true
            ;;
        *)
            DATABASE=true
            FIREWALL=true
            NGINX=true
            SHIELD=true
            TERMINAL=true
            VAGRANT=true
            ;;
    esac
    shift
done

# First connection
first_connection () {
  ## Update packages
  header "Update and upgrade packages for first time installation"

  aptitude update
  aptitude -y safe-upgrade

  # set locales to en_US.UTF-8
  export LANGUAGE=en_US.UTF-8
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  locale-gen en_US.UTF-8
  cecho "Set locale to en_US.UTF-8" $red
  dpkg-reconfigure locales

  cecho "Packages upgraded" $green

  ## update hostname
  # ❯ nano /etc/hostname

  cecho "Updated and upgraded" $green
}

# First protection
first_protection () {
  header "SSH shield"

  ## Root password
  cecho "Change root password..." $yellow

  passwd root

  cecho "Root password changed" $green

  ## New port
  cecho "Give a new server port for SSH: " $red
  read -r sshport

  ## Allow a group of users to connect
  cecho "Give a group name of users allow to connect: " $red
  read -r sshgroup
  groupadd $sshgroup

  cecho "Give a new user name allow to connect: " $red
  read -r newuser
  useradd -m $newuser
  passwd $newuser
  usermod -G $sshgroup $newuser
  usermod -G $sshgroup vagrant

  cecho "Group and user done " $green

  ## SSH configuration file
  cecho "SSH improvement..." $yellow

  sed -i "/^#/!s/Port .*/Port $sshport/" /etc/ssh/sshd_config
  sed -i '/^#/!s/PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i '/^#/!s/Protocol .*/Protocol 2/' /etc/ssh/sshd_config
  sed -i '/^#/!s/AllowGroups .*/#AllowGroups/' /etc/ssh/sshd_config
  sed -i '/^#/!s/AllowUsers .*/#AllowUsers/' /etc/ssh/sshd_config
  echo "AllowGroups $sshgroup" >> /etc/ssh/sshd_config

  /etc/init.d/ssh restart

  cecho "SSH done" $green


  ## SSH keys
  # mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys
  # chmod 0700 ~/.ssh
  # chmod 0600 ~/.ssh/authorized_keys
  # scp -R $sshport ~/.ssh/id_rsa.pub $newuser@xxx.xxx.x.xxx:/home/$newuser
  # cat /home/$newuser/id_rsa.pub >> ~/.ssh/authorized_keys

  ## SSH connection with vagrant
  # ssh vagrant@127.0.0.1 -p 2222
}

# Useless packages
useless_packages () {
  header "Remove useless packages (security weakness)"

  /etc/init.d/portmap stop
  /etc/init.d/nfs-kernel-server stop
  /etc/init.d/nfs-common stop
  /etc/init.d/apache2 stop

  update-rc.d -f portmap remove
  update-rc.d -f nfs-kernel-server remove
  update-rc.d -f nfs-common remove
  update-rc.d -f inetd remove

  aptitude --purge remove nfs-kernel-server nfs-common portmap ppp apache2

  cecho "Useless packages removed" $green
}

# Firewall
firewall () {
  header "Firewall"

  wget --no-check-certificate https://raw.githubusercontent.com/92bondstreet/genesis-debian/master/firewall.sh
  mv firewall.sh /etc/init.d/firewall.sh
  chmod +x /etc/init.d/firewall.sh
  sed -i "/^#/!s/TCP_SERVICES=\"22\" .*/TCP_SERVICES=\"$sshport\"/" /etc/init.d/firewall.sh

  /etc/init.d/firewall.sh start
  update-rc.d firewall.sh defaults

  cecho "Firewall done" $green
}

# Portsentry
portsentry () {
  header "Portsentry"

  aptitude -y install portsentry

  cecho "Add you IP Public in white list" $red
  read -r ippublic
  echo "$ippublic" >> /etc/portsentry/portsentry.ignore
  sed -i '/^#/!s/TCP_MODE=.*/TCP_MODE="atcp"/' /etc/default/portsentry
  sed -i '/^#/!s/UDP_MODE=.*/UDP_MODE="audp"/' /etc/default/portsentry
  sed -i '/^#/!s/BLOCK_UDP=.*/BLOCK_UDP="1"/' /etc/portsentry/portsentry.conf
  sed -i '/^#/!s/BLOCK_TCP=.*/BLOCK_TCP="1"/' /etc/portsentry/portsentry.conf
  sed -i '/^#/!s/KILL_ROUTE=.*/KILL_ROUTE="\/sbin\/route add -host \$TARGET\$ reject"/' /etc/portsentry/portsentry.conf
  sed -i 's/^#KILL_RUN_CMD=.*$/KILL_RUN_CMD="\/sbin\/iptables -I INPUT -s \$TARGET\$ -j DROP && \/sbin\/iptables -I INPUT -s \$TARGET\$ -m limit --limit 3\/minute --limit-burst 5 -j LOG --log-level debug "/' /etc/portsentry/portsentry.conf
  sed -i '/^#/!s/KILL_HOSTS_DENY=.*/KILL_HOSTS_DENY="ALL: \$TARGET\$ : DENY"/' /etc/portsentry/portsentry.conf

  /etc/init.d/portsentry restart

  cecho "Portsentry done" $green
}

# Fail2ban
fail2ban () {
  header "Fail2ban"

  aptitude -y install fail2ban

  cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
  sed -i '/^#/!s/bantime.*/bantime  = 900/' /etc/fail2ban/jail.local
  sed -i '/^#/!s/findtime.*/findtime  = 900/' /etc/fail2ban/jail.local

  /etc/init.d/fail2ban restart

  cecho "Fail2ban done" $green
}

# Backdoors
backdoors () {
  header "Backdoors"

  aptitude -y install rkhunter

  sed -i '/^#/!s/CRON_DAILY_RUN.*/CRON_DAILY_RUN="yes"/' /etc/default/rkhunter

  cecho "Backdoors done" $green
}

# Database
database () {
  header "Database installation"

  aptitude -y install postgresql postgresql-client postgresql-contrib php5-pgsql sudo
  wget --no-check-certificate -O phppgadmin.tar.gz http://downloads.sourceforge.net/phppgadmin/phpPgAdmin-5.1.tar.gz?download
  mkdir -p /var/www/phppgadmin
  tar -xvf phppgadmin.tar.gz -C /var/www/phppgadmin --strip-components=1
  sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
  sed -i '/^#/!s/peer/md5/' /etc/postgresql/9.4/main/pg_hba.conf
  /etc/init.d/postgresql restart
  cecho "Give a name of the user allows to connect to phppgadmin: " $red
  read -r phppgadminuser
  sudo -u postgres -i createuser --superuser --pwprompt $phppgadminuser
  sed -i "s/\$conf\['servers'\]\[0\]\['host'\].*/\$conf\['servers'\]\[0\]\['host'\] = 'localhost';/" /var/www/phppgadmin/conf/config.inc.php

  cecho "Database done" $green
}

# postgis
postgis () {
  header "Postgis installation"

  aptitude -y install postgis
  sudo -u postgres createuser gisuser
  sudo -u postgres createdb --encoding=UTF8 --owner=gisuser gis
  psql --username=postgres --dbname=gis -c "CREATE EXTENSION postgis;"
  psql --username=postgres --dbname=gis -c "CREATE EXTENSION postgis_topology;"

  cecho "Postgis done" $green
}

# Nginx
nginx () {
  header "NGinx, PHP-FPM and MemCached"

  wget --no-check-certificate https://raw.githubusercontent.com/92bondstreet/genesis-nginx/master/nginxautoinstall.sh
  chmod +x nginxautoinstall.sh
  mkdir -p $PWD/tmp-nginx
  mv nginxautoinstall.sh $PWD/tmp-nginx
  cd $PWD/tmp-nginx
  ./nginxautoinstall.sh
  update-rc.d nginx defaults
  cd $PWD
  rm -rf $PWD/tmp-nginx

  cecho "NGinx, PHP-FPM and MemCached done" $green
}

terminal () {
  ## zsh
  header "ZSH installation"

  aptitude -y install git zsh curl
  aptitude -y install zsh
  chsh -s $(which zsh)
  curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh
  sed -i '/^#/!s/ZSH_THEME.*/ZSH_THEME="pure"/' ~/.zshrc

  cecho "Restart your terminal to set oh-my-zsh installation" $green
  cecho "ZSH installed" $green
}

if $SHIELD; then
  first_connection
  first_protection
  useless_packages
  fail2ban
  backdoors
fi

if $FIREWALL; then
  firewall
  portsentry
fi

if $DATABASE; then
  database
fi

if $NGINX; then
  nginx
fi

if $TERMINAL; then
  terminal
fi

cecho "GENESIS \o/" $green
