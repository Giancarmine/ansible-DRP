Vagrant.require_version ">= 1.8.0"

Vagrant.configure(2) do |config|
  config.vm.box = "generic/ubuntu2204"
  config.ssh.insert_key = false
  config.vm.boot_timeout = 600
  config.vm.synced_folder '.', '/vagrant'

  config.vm.provision :ansible_local, run: "always" do |ansible|
    ansible.verbose = "vvv"
    ansible.playbook = "ubuntu.yml"
    ansible.compatibility_mode = "auto"
    ansible.extra_vars = {
      user: "vagrant"
    }
  end
end