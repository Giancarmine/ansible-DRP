Vagrant.require_version ">= 2.3.0"

Vagrant.configure("2") do |config|
  # Pin the box to the version validated in this repository. Bump it
  # deliberately: a floating box can change boot, network or package behaviour.
  config.vm.box = "alvistack/ubuntu-24.04"
  config.vm.box_version = "20260108.1.1"
  config.vm.boot_timeout = 600

  # 9p keeps the project visible inside the VM without an NFS server on the
  # host, so `vagrant up` works as an unprivileged user.
  config.vm.synced_folder ".", "/vagrant", type: "9p", accessmode: "mapped"

  config.vm.provider :libvirt do |libvirt|
    libvirt.memory = 4096
    libvirt.cpus = 4
  end

  # This box ships with cloud-init disabled, so Vagrant's generated 9p mount
  # metadata is not applied automatically. Mount the share ourselves before
  # the Ansible provisioner needs it.
  config.vm.provision "mount-9p", type: "shell", run: "always", inline: <<-'SHELL'
    set -e
    if mountpoint -q /vagrant; then exit 0; fi

    tag=""
    for f in /sys/bus/virtio/devices/*/mount_tag; do
      [ -r "$f" ] || continue
      candidate=$(tr -d '\0\n' < "$f" 2>/dev/null || true)
      if [ -n "$candidate" ] && [ "$candidate" != "9p" ]; then
        tag="$candidate"
        break
      fi
    done
    [ -n "$tag" ] || { echo "no 9p mount tag found" >&2; exit 1; }

    mkdir -p /vagrant
    mount -t 9p -o trans=virtio,version=9p2000.L,access=client "$tag" /vagrant
    grep -q " /vagrant " /etc/fstab || \
      echo "$tag /vagrant 9p trans=virtio,version=9p2000.L,access=client,_netdev,nofail 0 0" >> /etc/fstab
  SHELL

  config.vm.provision :ansible_local do |ansible|
    ansible.playbook = "ubuntu.yml"
    ansible.limit = "all"
    ansible.install = true
    ansible.compatibility_mode = "2.0"
    ansible.galaxy_role_file = "requirements.yml"
    ansible.galaxy_command = "ansible-galaxy collection install -r %{role_file}"
  end
end
