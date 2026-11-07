require "shellwords"
require "yaml"

Vagrant.require_version ">= 2.3.0"

# Keep the supported Ubuntu releases in one place. The CI workflow reads the
# same file to build its job matrix, so adding a version is a data change.
versions_file = File.join(__dir__, "ci", "ubuntu-versions.yml")
document = YAML.safe_load(File.read(versions_file), permitted_classes: [], aliases: false)
abort "#{versions_file}: expected a mapping with a versions list" unless document.is_a?(Hash)

versions = document["versions"]
unless versions.is_a?(Array) && !versions.empty?
  abort "#{versions_file}: versions must be a non-empty list"
end

enabled = versions.select { |version| version["enabled"] == true }
abort "#{versions_file}: no release is enabled" if enabled.empty?

requested = ENV["UBUNTU_VERSION"]
ubuntu =
  if requested.nil? || requested.empty?
    enabled.last
  else
    candidate = versions.find { |version| version["release"] == requested }
    if candidate.nil?
      known = versions.map { |version| version["release"] }.join(", ")
      abort "UBUNTU_VERSION=#{requested} is not defined in #{versions_file} (known: #{known})"
    end
    unless candidate["enabled"] == true
      abort "UBUNTU_VERSION=#{requested} is disabled in #{versions_file}; " \
            "enable it after validating its box"
    end
    candidate
  end

%w[release box box_version].each do |key|
  value = ubuntu[key]
  abort "#{versions_file}: selected entry is missing #{key}" unless value.is_a?(String) && !value.empty?
end

box = ubuntu.fetch("box")
box_version = ubuntu.fetch("box_version")
collections_path = File.join(__dir__, ".ansible", "collections")

Vagrant.configure("2") do |config|
  # One machine per release, so switching UBUNTU_VERSION does not reuse another
  # release's disk or box.
  config.vm.define "ubuntu-#{ubuntu['release']}" do |node|
    # Pin the box to the version validated in this repository. Bump it
    # deliberately: a floating box can change boot, network or package behaviour.
    node.vm.box = box
    node.vm.box_version = box_version
    node.vm.boot_timeout = 600

    # 9p keeps the project visible inside the VM without an NFS server on the
    # host, so `vagrant up` works as an unprivileged user.
    node.vm.synced_folder ".", "/vagrant", type: "9p", accessmode: "mapped"

    node.vm.provider :libvirt do |libvirt|
      libvirt.memory = 4096
      libvirt.cpus = 4
    end

    # This box ships with cloud-init disabled, so Vagrant's generated 9p mount
    # metadata is not applied automatically. Mount the share ourselves before
    # the Ansible provisioner needs it.
    node.vm.provision "mount-9p", type: "shell", run: "always", inline: <<-'SHELL'
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

    # Run Ansible from the host with the pinned controller version. The guest
    # only needs a target Python, which keeps older and newer Ubuntu releases
    # usable without installing a matching controller inside each box.
    node.vm.provision :ansible do |ansible|
      ansible.playbook = "ubuntu.yml"
      ansible.limit = "all"
      ansible.compatibility_mode = "2.0"
      # Vagrant 2.4 still passes --inventory-file, which ansible-core 2.23
      # removes. The wrapper translates it to --inventory, so the host
      # controller can move past 2.22 without waiting for Vagrant.
      ansible.playbook_command = File.expand_path("ci/ansible-playbook-compat", __dir__)
      ansible.galaxy_role_file = "requirements.yml"
      # Install into the checkout so Vagrant jobs do not modify the user's
      # global collection path. The wrapper uses the same ansible.cfg path.
      ansible.galaxy_command = "ansible-galaxy collection install --force " \
                               "--collections-path #{collections_path.shellescape} " \
                               "-r %{role_file}"
    end
  end
end
