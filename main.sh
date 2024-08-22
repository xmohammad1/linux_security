#!/bin/bash

block_ICMP() {
    # Remove any existing line with 'net.ipv4.icmp_echo_ignore_all'
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
    # Add the new line to block ICMP (ping) requests
    echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
    sysctl -p
}
change_ssh_port() {
        SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
        sudo sed -i -E 's/^(#Port |Port )[0-9]+/Port 64999/' "$SSHD_CONFIG_FILE"
        echo "SSH Port has been updated to Port 64999"
        sudo systemctl restart sshd
        sudo service ssh restart
        ufw allow 64999
}
fail2ban() {
    apt-get install -y fail2ban
    # Configure SSH protection
    cat <<EOT > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOT

    # Configure HTTP protection (basic DDoS mitigation)
    cat <<EOT >> /etc/fail2ban/jail.local
[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/apache2/access.log
maxretry = 300
findtime = 300
bantime = 3600
action = iptables[name=HTTP, port=http, protocol=tcp]
EOT

    # Create the filter for HTTP GET requests (basic DDoS mitigation)
    cat <<EOT > /etc/fail2ban/filter.d/http-get-dos.conf
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*
ignoreregex =
EOT

    # Restart Fail2Ban to apply configurations
    systemctl restart fail2ban
    systemctl enable fail2ban
}

remove_configurations() {
    # Remove the Fail2Ban package and its configurations
    systemctl stop fail2ban
    systemctl disable fail2ban
    apt-get remove --purge -y fail2ban
    rm -f /etc/fail2ban/jail.local /etc/fail2ban/filter.d/http-get-dos.conf
    echo "Fail2Ban and its configurations have been removed."

    # Remove UDP block rule
    iptables -D INPUT -p udp -j DROP
    iptables-save > /etc/iptables/rules.v4
    echo "UDP block rule removed."

    # Unblock ICMP (ping)
    sed -i '/net.ipv4.icmp_echo_ignore_all = 1/d' /etc/sysctl.conf
    sysctl -p
    echo "ICMP echo requests are no longer blocked."
}

menu() {
    while true; do
        echo "1) configure Anti DDoS script (Fail2ban ,UDP Block, Block ICMP)"
        echo "2) remove all configurations"
        echo "9) Exit"
        read -p "Enter your choice: " choice
        case $choice in
        1) fail2ban; block_ICMP; change_ssh_port; echo " All configurations activated";;
        2) remove_configurations;;
        9) exit;;
        *) echo "Invalid option. Please try again.";;
    esac
done
}
menu
