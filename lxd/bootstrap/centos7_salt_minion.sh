#!/bin/bash

/usr/bin/yum -t -q -y install https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm 
/usr/bin/yum -t -q -y clean expire-cache
/usr/bin/yum -t -q -y install salt-minion
/bin/rm -f /etc/salt/minion_id
/bin/cp /etc/hostname /etc/salt/minion_id
echo "fqdn: $(cat /etc/salt/minion_id)" >> /etc/salt/grains
/bin/sed -i.bak -e "s/#master: salt/master:\n  - $1/" /etc/salt/minion
/usr/bin/systemctl restart salt-minion.service
/usr/bin/systemctl enable salt-minion.service
