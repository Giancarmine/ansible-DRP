Vagrant.require_version ">= 1.8.0"

Vagrant.configure("2") do |config|
  boxes = [
    { :name => "ubuntu 22.04", :box => "generic/ubuntu2204" },
    { :name => "ubuntu 21.10", :box => "generic/ubuntu2110" }
  ]
  boxes.each do |opts|
    config.vm.define opts[:name] do |config|
      config.vm.box = opts[:box]
      if opts[:name] == boxes.last[:name]
        config.vm.provision "ansible" do |ansible|
          ansible.verbose = "vvv"
          ansible.playbook = "ubuntu.yml"
          ansible.limit = "all"
          ansible.compatibility_mode = "auto"
          ansible.extra_vars = {
            user: "vagrant"
          }
        end
      end
    end
  end
end
