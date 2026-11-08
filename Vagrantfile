# -*- mode: ruby -*-
# Vagrantfile - VM "clab-host": Ubuntu 24.04 + Docker Engine + containerlab
# Provider: VirtualBox 7.2.x, Vagrant 2.4.9
#
# Bien moi truong (khong phai sua file):
#   LAB_CPUS     so vCPU          (mac dinh 4; may yeu: 2)
#   LAB_MEM      RAM tinh bang MB (mac dinh 6144; may yeu: 4096)
#   LAB_BOX_URL  duong dan catalog box cuc bo, vd D:\vagrant-boxes\metadata.json
#                (dung khi cache box da bi xoa va HCP Vagrant khong con phuc vu)

VM_CPUS = (ENV["LAB_CPUS"] || 4).to_i
VM_MEM  = (ENV["LAB_MEM"]  || 6144).to_i
BOX_URL = ENV["LAB_BOX_URL"]

Vagrant.configure("2") do |config|
  config.vm.box              = "bento/ubuntu-24.04"
  config.vm.box_version      = "202510.26.0"   # ghim phien ban box de dung lai y het
  config.vm.box_url          = BOX_URL if BOX_URL && !BOX_URL.empty?
  config.vm.box_check_update = false            # khong hoi HCP Vagrant moi lan up
  config.vm.hostname         = "clab-host"
  config.vm.boot_timeout     = 600              # may cham hoac VirtualBox chay che do NEM

  # NIC1 luon la NAT (ra Internet, SSH 127.0.0.1:2222). NIC2 host-only de Windows thay VM.
  config.vm.network "private_network", ip: "192.168.56.10"

  # Thu muc repo tren Windows xuat hien trong VM tai /vagrant (vboxsf, hai chieu)
  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "clab-host"
    vb.cpus   = VM_CPUS
    vb.memory = VM_MEM
    vb.gui    = false
    # Khong bat nested VT-x: lab chi chay container, khong chay VM long.
    # Bo dau # neu apt trong VM loi DNS khi dung VPN hoac mang truong:
    # vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  # Cai Docker, containerlab, build image. Chay o lan "vagrant up" dau tien
  # hoac khi goi "vagrant provision".
  config.vm.provision "setup", type: "shell", path: "scripts/provision.sh"

  # Bridge br-srv (switch LAN may chu cua lab) mat sau moi lan khoi dong lai VM,
  # nen tao lai o MOI lan up/reload. Kem luat cho phep goi di qua br-srv,
  # vi Docker dat FORWARD policy DROP (scripts/deploy.sh cung lam lai viec nay).
  config.vm.provision "br-srv", type: "shell", run: "always", inline: <<-SHELL
    ip link show br-srv >/dev/null 2>&1 || ip link add br-srv type bridge
    ip link set br-srv up
    if iptables -nL DOCKER-USER >/dev/null 2>&1; then
      iptables -C DOCKER-USER -i br-srv -o br-srv -j ACCEPT 2>/dev/null || \
        iptables -I DOCKER-USER -i br-srv -o br-srv -j ACCEPT
    fi
  SHELL
end
