# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

Vagrant.configure("2") do |config|
    config.vm.box = "debian/bookworm64"

    config.vm.box_check_update = false
    config.ssh.insert_key = false
    # insecure_private_key download from https://github.com/hashicorp/vagrant/blob/master/keys/vagrant
    config.ssh.private_key_path = "insecure_private_key"

    my_machines = {
        'vm4'   => '192.168.33.4',
        'vm5'   => '192.168.33.5',
        'vm6'   => '192.168.33.6',
        'vm7'   => '192.168.33.7',
        'vm8'   => '192.168.33.8',
    }

    my_machines.each do |name, ip|
        config.vm.define name do |machine|
            machine.vm.network "private_network", ip: ip

            machine.vm.hostname = name
            machine.vm.provider :virtualbox do |vb|
                #vb.name = name  
                vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
                vb.customize ["modifyvm", :id, "--vram", "32"]
                vb.customize ["modifyvm", :id, "--ioapic", "on"]
                vb.customize ["modifyvm", :id, "--cpus", "2"]
                vb.customize ["modifyvm", :id, "--memory", "4096"]
            end

            machine.vm.provision "shell", inline: <<-SHELL
                echo "root:vagrant" | sudo chpasswd
                timedatectl set-timezone "Asia/Shanghai"
                bash /vagrant/scripts/init-os.sh
                bash /vagrant/scripts/install-containerd.sh
            SHELL

            if name == "vm4"
                machine.vm.provision "shell", inline: <<-SHELL
                    bash /vagrant/scripts/install-etcd.sh --ver "v3.5.9"
                    wait4x tcp -i 2s -t 300s 127.0.0.1:2379 && etcdctl put /coreos.com/network/config '{ "Network": "10.5.0.0/16", "Backend": {"Type": "vxlan"} }'
                SHELL
            end

            if name == "vm4" or name == "vm5" or name == "vm6"
                machine.vm.provision "shell", inline: <<-SHELL
                    bash /vagrant/scripts/install-consul.sh --server --ver "1.16.1"
                    bash /vagrant/scripts/install-nomad.sh --server --ver "1.6.1"
                SHELL
            else
                machine.vm.provision "shell", inline: <<-SHELL
                    bash /vagrant/scripts/install-consul.sh --ver "1.16.1"
                    bash /vagrant/scripts/install-nomad.sh --ver "1.6.1"
                SHELL
            end

            machine.vm.provision "shell", inline: <<-SHELL
                wait4x tcp -i 2s -t 300s 192.168.33.4:2379 && bash /vagrant/scripts/install-flanneld.sh
                bash /vagrant/scripts/install-cni-configs.sh
            SHELL


        end
    end




end