#!/bin/bash -e

echo "* Creating user pwnagotchi"

ls -l /tmp/overlay

PUSER=pwnagotchi
PHOME=/home/${PUSER}
PGROUPS=adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,render,netdev,i2c

useradd -c "Pwnagotchi" -p $(echo pwny1234 | openssl passwd -1 -stdin) -G ${PGROUPS} -d ${PHOME} -m ${PUSER} -k /etc/skel -s /bin/bash

if ! grep "pwnagotchi addons" ${PHOME}/.bashrc ; then
    echo "* Adding pwnagotchi aliases to .bashrc"
    cat >>${PHOME}/.bashrc <<EOF

# pwnagotchi addons

PWND_LSFLAGS="-ltrcd --time ctime"
# monthly, daily handshakes histogram
alias pwnd_monthly="ls ${PWND_LSFLAGS} /root/handshakes/*.pcap | cut -c 33-35 | uniq -c"
alias pwnd_daily="ls ${PWND_LSFLAGS} /root/handshakes/*.pcap | cut -c 33-39 | uniq -c"

# handshakes captured today
alias pwnd_today='ls -ltrcd /root/handshakes/*|  grep "\$(date +'\''%b %_d'\'')"'

# 
alias pwncpu="grep -a '\[epoch' /var/log/pwnagotchi.log  | cut -d ' ' -f 23 | sort -n -k1.5 | uniq -c"
alias pwncpu100="grep -a '\[epoch' /var/log/pwnagotchi.log | tail -100 | cut -d ' ' -f 23 | sort -n -k1.5 | uniq -c"

# show pwnagotchi process threads
alias pwnthreads='watch -n 1 "echo -n "Plugins enabled: " ; egrep -c "plugins.[^\.]*.enabled.*true" /etc/pwnagotchi/config.toml ; echo -n "Pwny Threads: "; ps -L -O lwp,pcpu -C pwnagotchi | wc -l  ; ps -L -O lwp,pcpu -C pwnagotchi"'

alias pwnkill='sudo killall -USR1 pwnagotchi'
alias pwnver='python3 -c \"import pwnagotchi as p; print(p.__version__)\"'
alias pwnlog='tail -f -n300 /var/log/pwn*.log | sed --unbuffered \"s/,[[:digit:]]\\{3\\}\\]//g\" | cut -d \" \" -f 2-'

PATH=${PATH}:/sbin:/usr/sbin:/usr/local/sbin
EOF

fi

echo "Set up venv"

python3 -m venv /home/${PUSER}/.venv
sed -i -e 's/include-system-site-packages.*=.*false/include-system-site-packages = true/' /home/${PUSER}/.venv/pyvenv.cfg