#!/bin/bash
# Script d'installation de l'agent observium. Teste sur: Debian 7,8 64bits
# Variables Couleurs / Réinitialise les couleurs à la normale : tput sgr0
VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
ROUGE="\\033[1;31m"
ROSE="\\033[1;35m"
BLEU="\\033[1;34m"
BLANC="\\033[0;02m"
BLANCLAIR="\\033[1;08m"
JAUNE="\\033[1;33m"
CYAN="\\033[1;36m"
CEND="${CSI}0m"

## check root
if [ $UID -ne 0 ]; then
        echo -e "$ROUGE" "You need execute as root"
        echo -e "$ROUGE" "Ex: sudo ./observium_agent.sh"
        exit 1
fi
tput sgr0

## 	Config
## set Community SNMP
clear
echo -e "$BLEU"
read -p "Community SNMP (public, private..):   " SNMP_COMMUNITY

## set Email Contact
read -p "Mail contact:   " SYSCONTACT

## set server location
read -p "Location:    " SYSLOCATION

## IP Observium
read -p "Observium's IP for Xinetd agent:       " IPOBSERVIUM
tput sgr0

# Pckgs
apt-get install snmpd xinetd nano telnet

# Dl des scripts
mkdir -p /opt/observium && cd /opt
wget http://www.observium.org/observium-community-latest.tar.gz
tar zxvf observium-community-latest.tar.gz

# Options daemon snmp
sed -e "/SNMPDOPTS=/ s/^#*/SNMPDOPTS='-Lsd -Lf \/dev\/null -u snmp -p \/var\/run\/snmpd.pid'\n#/" -i /etc/default/snmpd

# Logos Distros
mv /opt/observium/scripts/distro /usr/bin/distro
chmod 755 /usr/bin/distro

# Conf snmp
mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.org
cat >/etc/snmp/snmpd.conf <<EOL
com2sec readonly  default         $SNMP_COMMUNITY
group MyROGroup v1         readonly
group MyROGroup v2c        readonly
group MyROGroup usm        readonly
view all    included  .1                               80
access MyROGroup ""      any       noauth    exact  all    none   none
syslocation $SYSLOCATION
syscontact $SYSCONTACT
#This line allows Observium to detect the host OS if the distro script is installed
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/bin/distro 
EOL

# Copie
cp observium/scripts/observium_agent_xinetd /etc/xinetd.d/observium_agent
echo "" > /etc/xinetd.d/observium_agent

# changez "only_from" par votre IP Observium 
cat > /etc/xinetd.d/observium_agent <<END
service observium_agent
{
        type           = UNLISTED
        port           = 36602
        socket_type    = stream
        protocol       = tcp
        wait           = no
        user           = root
        server         = /usr/bin/observium_agent

        # configure the IPv[4|6] address(es) of your Observium server here:
        only_from      = $IPOBSERVIUM

        # Don't be too verbose. Don't log every check. This might be
        # commented out for debugging. If this option is commented out
        # the default options will be used for this service.
        log_on_success =

        disable        = no
}
END

# Script Observium
cp observium/scripts/observium_agent /usr/bin/observium_agent
chmod +x /usr/bin/observium_agent
mkdir -p /usr/lib/observium_agent/local


# Copie des Agents locaux
cd /opt
cp observium/scripts/agent-local/apache /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/bind /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/dpkg /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/drbd /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/exim-mailqueue.sh /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/hdarray /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/ipmitool-sensor /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/memcached /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/munin /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/mysql /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/mysql.cnf /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/nfs /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/nginx /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/ntpd /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/postfix_mailgraph /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/postfix_qshape /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/postgresql.conf /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/postgresql.pl /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/temperature /usr/lib/observium_agent/local/
cp observium/scripts/agent-local/zimbra  /usr/lib/observium_agent/local/

# Régles IPTables Observium 
iptables -I INPUT -s $IPOBSERVIUM -p tcp --dport 36602 -j ACCEPT

# Restart des services
/etc/init.d/xinetd restart
/etc/init.d/snmpd restart 

## Fini
clear
echo "Install finish"
exit 0;
