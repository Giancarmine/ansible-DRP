Vagrant.configure("2") do |config| 
    config.vm.box = "generic/ubuntu2004" 
    
    config.vm.provider "libvirt" do |libvirt| 
        libvirt.memory = "4024"
        libvirt.cpus = "1"
    end    
    
    # config.vm.provision "ansible" do |ansible|
    #     ansible.become = true
    #     ansible.verbose = "v"        
    #     ansible.extra_vars = "vars.yml"
    #     ansible.playbook = "ubuntu.yaml"
    # end
end