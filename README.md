# genesis-debian

> Automagic installation of Debian

## Usage

**Note:** Root only

```sh
❯ wget --no-check-certificate https://raw.githubusercontent.com/92bondstreet/genesis/master/genesis.sh
❯ chmod +x ./genesis.sh
❯ sh genesis.sh
```

## Production

```sh
❯ sh genesis.sh --production
```

## Steps

1. **[production only]** Update and upgrade packages for first time installation"
1. **[production only]** SSH shield
1. Remove useless packages (security weakness)
1. **[production only]** Firewall
1. **[production only]** Portsentry
1. Fail2ban
1. Backdoors
1. Postgresql Database installation
1. NGinx, PHP-FPM and MemCached
1. ZSH installation and terminal

## Installation available beyond steps

1. postgis

## Deep diving

* [Securing Debian Manual
Chapter 5 - Securing services running on your system](https://www.debian.org/doc/manuals/securing-debian-howto/ch-sec-services.en.html)
* [Secure SSH](http://www.debian-administration.org/article/455/Secure_SSH)
* [Aptitude vs Apt-Get](https://pthree.org/2007/08/12/aptitude-vs-apt-get/)
* [How To Set Up SSH Keys](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2)
* [Cron-apt : Installation des mises à jour de sécurité automatique](https://wiki.deimos.fr/Cron-apt_:_Installation_des_mises_%C3%A0_jour_de_s%C3%A9curit%C3%A9_automatique)
* [Building a Vagrant Box from Start to Finish](https://blog.engineyard.com/2014/building-a-vagrant-box)
* [Guide sur l’installation d’un serveur sous Debian 7 (Wheezy)](http://elliptips.info/guide-sur-linstallation-dun-serveur-sous-debian-7-wheezy/)
* [Linux + Nginx + PHP-FPM + MySQL (LEMP) Development VM With Vagrant](https://vesselinv.com/lemp-with-vagrant/)
