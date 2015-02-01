#!/bin/sh -
set -o errexit
set -o nounset

# This script provides an easy install of Ambari
# for RedHat Enterpise Linux 6 & CentOS 6

# defaults: override by setting in the environment
#   For example:
#       export java_provider=oracle
#       export install_ambari_server=true
#       sh ambari-bootstrap.sh

install_ambari_agent="${install_ambari_agent:-true}"
install_ambari_server="${install_ambari_server:-false}"
java_provider="${java_provider:-open}" # accepts: open, oracle
ambari_server="${ambari_server:-127.0.0.1}"
ambari_version="${ambari_version:-1.7.0}"
ambari_repo="${ambari_repo:-http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/${ambari_version}/ambari.repo}"
curl="curl -sSL"

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

if [ ! "$(hostname -f)" ]; then
    echo >&2 'Error: "hostname -f" failed to report an FQDN.'
    echo >&2 'The system must report a FQDN in order to use Ambari'
    exit 1
fi

if [ "$(id -ru)" != 0 ]; then
    echo >&2 'Error: this installer needs the ability to run commands as root.'
    echo >&2 'Install as root or with sudo'
    exit 1
fi

case "$(uname -m)" in
    *64)
        ;;
    *)
        echo >&2 'Error: you are not using a 64bit platform.'
        echo >&2 'This installer requires a 64bit platforms.'
        exit 1
        ;;
esac

if command_exists ambari-agent || command_exists ambari-server; then
    echo >&2 'Warning: "ambari-agent" or "ambari-server" command appears to already exist.'
    echo >&2 'Please ensure that you do not already have ambari-agent installed.'
    echo >&2 'You may press Ctrl+C now to abort this process and rectify this situation.'
    ( set -x; sleep 20 )
fi

my_disable_thp() {
    ( cat > /usr/local/sbin/ambari-thp-disable.sh <<-'EOF'
#!/usr/bin/env bash
# disable transparent huge pages: for Hadoop
thp_disable=true
if [ "${thp_disable}" = true ]; then
    for path in redhat_transparent_hugepage transparent_hugepage; do
        for file in enabled defrag; do
            if test -f /sys/kernel/mm/${path}/${file}; then
                echo never > /sys/kernel/mm/${path}/${file}
            fi
        done
        if test -f /sys/kernel/mm/${path}/khugepaged/defrag; then
            echo no > /sys/kernel/mm/${path}/khugepaged/defrag
        fi
    done
fi
exit 0
EOF
    )
    chmod +x /usr/local/sbin/ambari-thp-disable.sh
    sh /usr/local/sbin/ambari-thp-disable.sh
    echo -e '\nsh /usr/local/sbin/ambari-thp-disable.sh || /bin/true\n' >> /etc/rc.local
}

yum install -y curl ntp openssl python zlib

(
    set +o errexit

    setenforce 0
    sed -i 's/\(^[^#]*\)SELINUX=enforcing/\1SELINUX=disabled/' /etc/selinux/config
    sed -i 's/\(^[^#]*\)SELINUX=permissive/\1SELINUX=disabled/' /etc/selinux/config

    my_disable_thp

    echo 'Defaults !requiretty' > /etc/sudoers.d/888-dont-requiretty

    chkconfig iptables off && service iptables stop
    chkconfig ip6tables off && service ip6tables stop
    chkconfig ntpd on && ntpd -q && service ntpd restart
)

if [ "${java_provider}" != 'oracle' ]; then
    yum install -y java7-devel
    mkdir -p /usr/java
    ln -s /etc/alternatives/java_sdk /usr/java/default
    JAVA_HOME='/usr/java/default'
fi

${curl} -o /etc/yum.repos.d/ambari.repo \
    "${ambari_repo}"

if [ "${install_ambari_agent}" = true ]; then
    yum install -y ambari-agent
    sed -i.orig -r 's/^[[:space:]]*hostname=.*/hostname='"${ambari_server}"'/' \
        /etc/ambari-agent/conf/ambari-agent.ini
    ambari-agent start
fi
if [ "${install_ambari_server}" = true ]; then
    yum install -y ambari-server
    if [ "${java_provider}" = 'oracle' ]; then
        ambari-server setup -s
    else
        ambari-server setup -j "${JAVA_HOME}" -s
    fi
    ambari-server start
fi
