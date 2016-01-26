# -*- mode: ruby -*-
# vi: set ft=ruby :

hostname = ENV['HOSTNAME'] ? ENV['HOSTNAME'] : 'st2packages'

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

    config.vm.network "public_network", bridge: "en0: Ethernet"
    # config.vm.network "private_network", ip: "172.168.100.67"

    name = hostname

    config.vm.define "u14" do |u14|
      u14.vm.box = 'puppetlabs/ubuntu-14.04-64-nocm'
      u14.vm.provision "shell", inline: "cat /vagrant/bootstrap-trusty.sh | sudo su"
      u14.vm.provision "shell", inline: "cat /vagrant/banner", keep_color: true
      name = "#{hostname}-u14"
    end

    config.vm.define "el6" do |el6|
      el6.vm.box = 'puppetlabs/centos-6.6-64-nocm'
      el6.vm.provision "shell", inline: "cat /vagrant/bootstrap-el6.sh | sudo su"
      el6.vm.provision "shell", inline: "cat /vagrant/banner", keep_color: true
      name = "#{hostname}-el6"
    end

    config.vm.define "el7" do |el7|
      el7.vm.box = 'puppetlabs/centos-7.0-64-nocm'
      el7.vm.provision "shell", inline: "cat /vagrant/bootstrap-el7.sh | sudo su"
      el7.vm.provision "shell", inline: "cat /vagrant/banner", keep_color: true
      name = "#{hostname}-el7"
    end

    config.vm.hostname = name

    config.vm.provider :virtualbox do |vb|
      vb.name = "#{name}"
      vb.memory = 2048
      vb.cpus = 2
    end


end
