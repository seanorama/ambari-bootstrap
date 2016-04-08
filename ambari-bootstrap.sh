#!/bin/sh -
set -o errexit
set -o nounset
set -o pipefail

# This script provides an easy install of Ambari
# for RedHat Enterpise Linux 6 & CentOS 6
#
# source at http://github.com/seanorama/ambari-bootstrap
#
# Download and run as root or with sudo. Or alternatively:
#   curl -sSL https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/ambari-bootstrap.sh | sudo -E sh
#
# defaults can be overriden by setting variables in the environment:
#   For example:
#       export java_provider=oracle
#       export install_ambari_server=true
#       sh ambari-bootstrap.sh

install_ambari_agent="${install_ambari_agent:-true}"
install_ambari_server="${install_ambari_server:-false}"
iptables_disable="${iptables_disable:-true}"
java_install="${java_install:-true}"
java_provider="${java_provider:-open}" # accepts: open, oracle
java_version="${java_version:-7}"
java_path="${java_path:/etc/alternatives/java_sdk}"
ambari_server="${ambari_server:-localhost}"
ambari_version="${ambari_version:-2.2.1.0}"
ambari_version_major="${ambari_version_major:-$(echo ${ambari_version} | cut -c 1).x}"
ambari_server_custom_script="${ambari_server_custom_script:-/bin/true}"
ambari_protocol="${ambari_protocol:-http}"
ambari_user="${ambari_user:-root}"
ambari_setup_switches="${ambari_setup_switches:-}"
##ambari_repo= ## if using a local repo. Otherwise the repo path is determined automatically in a line below.
curl="curl -ksSL"

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

if [ ! "$(hostname -f)" ]; then
    printf >&2 'Error: "hostname -f" failed to report an FQDN.\n'
    printf >&2 'The system must report a FQDN in order to use Ambari\n'
    exit 1
fi

if [ "$(id -ru)" != 0 ]; then
    printf >&2 'Error: this installer needs the ability to run commands as root.\n'
    printf >&2 'Install as root or with sudo\n'
    exit 1
fi

case "$(uname -m)" in
    *64)
        ;;
    *)
        printf >&2 'Error: you are not using a 64bit platform.\n'
        printf >&2 'This installer requires a 64bit platforms.\n'
        exit 1
        ;;
esac

## basic platform detection
lsb_dist=''
if [ -z "${lsb_dist}" ] && [ -r /etc/centos-release ]; then
    lsb_dist='centos'
    lsb_dist_release=$(awk '{print $(NF-1)}' /etc/centos-release | cut -d "." -f1)
fi
if [ -z "${lsb_dist}" ] && [ -r /etc/redhat-release ]; then
    lsb_dist='centos'
    lsb_dist_release=$(awk '{print $(NF-1)}' /etc/redhat-release | cut -d "." -f1)
fi
lsb_dist="$(echo "${lsb_dist}" | tr '[:upper:]' '[:lower:]')"

ambari_repo="${ambari_repo:-http://public-repo-1.hortonworks.com/ambari/${lsb_dist}${lsb_dist_release}/${ambari_version_major}/updates/${ambari_version}/ambari.repo}"

if command_exists ambari-agent || command_exists ambari-server; then
    printf >&2 'Warning: "ambari-agent" or "ambari-server" command appears to already exist.\n'
    printf >&2 'Please ensure that you do not already have ambari-agent installed.\n'
    printf >&2 'You may press Ctrl+C now to abort this process and rectify this situation.\n'
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
    done
fi
exit 0
EOF
    )
    chmod +x /usr/local/sbin/ambari-thp-disable.sh
    sh /usr/local/sbin/ambari-thp-disable.sh
    printf '\nsh /usr/local/sbin/ambari-thp-disable.sh || /bin/true\n\n' >> /etc/rc.local
}

my_ambari_https() {
    printf 'api.ssl=true\nclient.api.ssl.cert_name=https.crt\nclient.api.ssl.key_name=https.key\nclient.api.ssl.port=8444' >> /etc/ambari-server/conf/ambari.properties
    mkdir /root/ambari-cert
    cd /root/ambari-cert
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout server.key -out server.crt -batch
    echo PulUuMWPp0o4Lq6flGA0NGDKNRZQGffW2mWmJI3klSyspS7mUl > pass.txt
    openssl pkcs12 -export -in 'server.crt' -inkey 'server.key' -certfile 'server.crt' -out '/var/lib/ambari-server/keys/https.keystore.p12'  -password file:pass.txt 
    mv pass.txt /var/lib/ambari-server/keys/https.pass.txt
    cd ..
    rm -rf /root/ambari-cert
}

my_disable_ipv6() {
    mkdir -p /etc/sysctl.d
    ( cat > /etc/sysctl.d/99-hadoop-ipv6.conf <<-'EOF'
## Disabled ipv6
## Provided by Ambari Bootstrap
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    )
    sysctl -e -p /etc/sysctl.d/99-hadoop-ipv6.conf
}




case "${lsb_dist}" in
    centos|redhat)

    case "${lsb_dist_release}" in
        6|7)

        (
            set +o errexit

            printf "## Info: Installing base packages\n"
            packages="curl openssl python zlib wget unzip openssh-clients"
            if [ "${system_config}" = true ]; then
                packages+=" ntp"
                setenforce 0 || true
                sed -i 's/\(^[^#]*\)SELINUX=enforcing/\1SELINUX=disabled/' /etc/selinux/config
                sed -i 's/\(^[^#]*\)SELINUX=permissive/\1SELINUX=disabled/' /etc/selinux/config
            if [ "${system_config}" = true ]; then
fi
            yum install -y -q ${packages}

            printf "## Info: Disabling IPv6\n"
            my_disable_ipv6

            printf "## Raising file limits\n"
            ( cat > /etc/security/limits.d/90-hdp.conf <<-'EOF'
* soft nofile 32768
* hard nofile 32768
* soft nproc 32768
* hard nproc 32768
EOF
            )

            printf "## Info: Fixing sudo to not requiretty. This is the default in newer distributions\n"
            printf 'Defaults !requiretty\n' > /etc/sudoers.d/888-dont-requiretty

            printf "## Info: Disabling Transparent Huge Pages\n"
            my_disable_thp

            if [ "${iptables_disable}" = true ]; then
                printf "## Info: Disabling iptables\n"
                chkconfig iptables off || true
                service iptables stop || true
                chkconfig ip6tables off || true
                service ip6tables stop || true
            fi

            printf "## Syncing time via ntpd\n"
            ntpd -qg || true
            chkconfig ntpd on || true
            service ntpd restart || true
        )

        if [ "${java_provider}" != 'oracle' ]; then
            printf "## installing java\n"
            yum install -q -y java-1.${java_version}.0-openjdk-devel
            JAVA_HOME=${java_path}
            echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment
            ambari_setup_switches="${ambari_setup_switches} -j ${JAVA_HOME}"
        fi

        printf "## fetch ambari repo\n"
        ${curl} -o /etc/yum.repos.d/ambari.repo \
            "${ambari_repo}"

        if [ "${install_ambari_agent}" = true ]; then
            printf "## installing ambari-agent\n"
            yum install -q -y ambari-agent
            sed -i.orig -r 's/^[[:space:]]*hostname=.*/hostname='"${ambari_server}"'/' \
                /etc/ambari-agent/conf/ambari-agent.ini
            chkconfig ambari-agent on
            ambari-agent start
        fi
        if [ "${install_ambari_server}" = true ]; then
            printf "## install ambari-server\n"
            yum install -q -y ambari-server

            if [ "${ambari_user}" != root]; then
                useradd -r ${ambari_user}
                ambari_setup_switches="${ambari_setup_switches} --service-user-name ${ambari_user}"
            fi

            echo ${ambari_setup_switches}
            ambari-server setup -s "${ambari_setup_switches}"

            if [ "${ambari_protocol}" = "https" ]; then
                my_ambari_https
            fi

            sh -c "${ambari_server_custom_script}"

            chkconfig ambari-server on
            if ! nohup sh -c "ambari-server start 2>&1 > /dev/null"; then
                printf 'Ambari Server failed to start\n' >&2
            fi
        fi
        printf "## Success! All done.\n"
        exit 0
    ;;
    esac
;;
esac

cat >&2 <<'EOF'

  Your platform is not currently supported by this script or was not
  easily detectable.

  The script currently supports:
    Red Hat Enterprise Linux 6 & 7
    CentOS 6 & 7

  Please visit the following URL for more detailed installation
  instructions:

    https://docs.hortonworks.com/

EOF
exit 1

