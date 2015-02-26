# -*- mode: ruby -*-
# vi: set ft=ruby :

NUM_BOXES = 3
IP_OFFSET = 10

def ip_from_num(i)
    "10.0.0.#{100+i+IP_OFFSET}"
end

Vagrant.configure(2) do |config|
  config.ssh.pty = true

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true

  (1..NUM_BOXES).each do |i|
    is_main = (i == 1)

    config.vm.define "v#{i}".to_sym do |v2|
      v2.vm.box = "centos6.5"
      #config.vm.box = "hashicorp/precise64"
      #config.vm.box = "ubuntu/precise64"
      #config.vm.box = "puppetlabs/ubuntu-12.04-64-nocm"
      #config.vm.box = "centos6.5"
      #config.vm.box = "chef/centos-6.5"
      #config.vm.box = "puppetlabs/centos-6.5-64-nocm"

      v2.vm.hostname = "v#{i}.localdomain"
      v2.vm.network "private_network", ip: ip_from_num(i)
      #v2.vm.network "private_network", type: :dhcp

      v2.vm.provider :virtualbox do |v, override|
        #override.ssh.private_key_path = "~/.ssh/id_rsa"
        #override.ssh.username = "ec2-user"
        v.customize ["modifyvm", :id, "--cpus", "1", "--memory", "1024"]
        override.ssh.pty = true
        #override.ssh.private_key_path = "~/.ssh/id_rsa"
      end

      v2.vm.provision "shell" do |s|
        if is_main
          s.inline = "install_ambari_server=true sh /vagrant/ambari-bootstrap.sh"
        else
          s.inline = "ambari_server=$1 sh /vagrant/ambari-bootstrap.sh"
          s.args   = ip_from_num(1)
        end
      end

    end

  end

end
