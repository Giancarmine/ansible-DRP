Vagrant.require_version ">= 1.8.0"

Vagrant.configure("2") do |config|
#  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.box = "generic/ubuntu2204"
#  config.vm.network 'private_network', ip: '192.168.22.4'
  config.vm.synced_folder ".", "/vagrant"

  config.vm.provision :ansible_local do |ansible|
    ansible.playbook = "ubuntu.yml"
	ansible.limit = 'all'
  end
end