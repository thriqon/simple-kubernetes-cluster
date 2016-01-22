
minions = 5

boxurl = "http://alpha.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"

Vagrant.configure("2") do |config|
	config.vm.box = "coreos-alpha"
	config.vm.box_url = boxurl

	config.vm.define "master" do |n|
		n.vm.hostname = "master.cluster"
		n.vm.network :private_network, ip: "192.168.50.100"

		n.vm.provision :file, source: "tls/ca.pem", destination: "/tmp/ca.pem"
		n.vm.provision :file, source: "tls/apiserver.pem", destination: "/tmp/apiserver.pem"
		n.vm.provision :file, source: "tls/apiserver-key.pem", destination: "/tmp/apiserver-key.pem"

		n.vm.provision :file, source: "master-manifests", destination: "/tmp/"

		n.vm.provision :shell, path: "master-provision.sh", privileged: true
	end

	config.vm.define "etcd" do |n|
		n.vm.hostname = "etcd.cluster"
		n.vm.network :private_network, ip: "192.168.50.101"
		n.vm.provision :shell, inline: "mkdir -p /etc/systemd/system/etcd2.service.d/", privileged: true
		n.vm.provision :shell, inline: 'echo "[Service]" > /etc/systemd/system/etcd2.service.d/40-listen-address.conf', privileged: true
		n.vm.provision :shell, inline: 'echo "Environment=ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379" >> /etc/systemd/system/etcd2.service.d/40-listen-address.conf', privileged: true
		n.vm.provision :shell, inline: 'echo "Environment=ETCD_ADVERTISE_CLIENT_URLS=http://192.168.50.101:2379" >> /etc/systemd/system/etcd2.service.d/40-listen-address.conf', privileged: true
		n.vm.provision :shell, inline: "systemctl start etcd2", privileged: true
		n.vm.provision :shell, inline: "systemctl enable etcd2", privileged: true
	end

	minions.times do |i|
		config.vm.define "minion-#{i}" do |n|
			n.vm.hostname = "minion#{i}.cluster"
			n.vm.network :private_network, ip: "192.168.50.#{i + 111}"
		end
	end
end
