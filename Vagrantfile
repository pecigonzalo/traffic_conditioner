# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
setup_traffic = File.read('scripts/setup_traffic.sh')
setup_switch = File.read('scripts/setup_switch.sh')
setup_common = File.read('scripts/setup_common.sh')

Vagrant.configure(2) do |config|
  config.vm.provision :fix_tty, type: 'shell' do |s|
    s.privileged = false
    s.inline = "sudo sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile"
  end
  config.vm.box = 'ubuntu/trusty64'

  config.vm.provision :shell, inline: setup_common

  config.vm.define :www do |www|
    www.vm.hostname = 'www'
    www.vm.network 'private_network', ip: '192.168.222.50',
                                      virtualbox__intnet: 'traffic_TO_www'
    www.vm.provision :shell, inline: setup_www
  end

  config.vm.define :traffic do |traffic|
    traffic.vm.hostname = 'traffic'
    traffic.vm.network 'private_network', ip: '192.168.222.20',
                                          virtualbox__intnet: 'traffic_TO_www'
    traffic.vm.network 'private_network', ip: '192.168.200.20',
                                          virtualbox__intnet: 'switch_TO_traffic'
    traffic.vm.provision :shell, inline: setup_switch
    traffic.vm.synced_folder './scripts', '/home/vagrant/scripts'
    traffic.vm.provision :shell, inline: 'chmod +x /home/vagrant/scripts/*'
  end

  config.vm.define :switch do |switch|
    switch.vm.hostname = 'switch'
    switch.vm.network 'private_network', ip: '192.168.200.10',
                                         virtualbox__intnet: 'switch_TO_traffic'
    switch.vm.network 'private_network', ip: '192.168.50.10'
    switch.vm.provision :shell, inline: setup_switch
  end
end
