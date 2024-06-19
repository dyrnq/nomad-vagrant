# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
ETCD_VER="v3.5.11"
CONSUL_VER="1.19.0"
NOMAD_VER="1.8.0"
FLANNELD_VER="v0.25.4"
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
                    bash /vagrant/scripts/install-etcd.sh --ver "#{ETCD_VER}"
                    wait4x tcp -i 2s -t 300s 127.0.0.1:2379 && etcdctl put /coreos.com/network/config '{ "Network": "10.5.0.0/16", "Backend": {"Type": "vxlan"} }'
                SHELL
            end

            if /^vm[456]$/.match?(name)
                machine.vm.provision "shell", inline: <<-SHELL
                    bash /vagrant/scripts/install-consul.sh --server --ver "#{CONSUL_VER}"
                    bash /vagrant/scripts/install-nomad.sh --server --ver "#{NOMAD_VER}"
                SHELL
            else
                machine.vm.provision "shell", inline: <<-SHELL
                    bash /vagrant/scripts/install-consul.sh --ver "#{CONSUL_VER}"
                    bash /vagrant/scripts/install-nomad.sh --ver "#{NOMAD_VER}"
                SHELL
            end

            machine.vm.provision "shell", inline: <<-SHELL
                wait4x tcp -i 2s -t 300s 192.168.33.4:2379 && bash /vagrant/scripts/install-flanneld.sh --ver "#{FLANNELD_VER}"
                bash /vagrant/scripts/install-cni-configs.sh
            SHELL


        end
    end


    hetero_machines = {
        'vm14'   => '192.168.33.14',
        'vm15'   => '192.168.33.15',
    }

    hetero_machines.each do |name, ip|
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



            if name == "vm14"
                machine.vm.provision "shell", inline: <<-SHELL
                    bash /vagrant/scripts/install-kafka.sh
                SHELL
            end


        end
    end


end