
	Controller Installation Checklist

	Set-up 1 - VM								Set-up 2 - Bare Metal Server

	HW Config

	Virtual	Recommended	Actual						Bare Metal	Recommended	Actual
	VCPU (cores)	1-2+	2						CPU	1+	4
	RAM	4+ GB	6						RAM	16+	32
	Primary Disk	10+ GB	20						Primary Disk	128+ GB, SSD preffered	512GB

	VirtualBox Host-Only Network Ethernet Adapter #2
	Configure Adapter Manualy		IPv4 Addr	10.0.0.1	IPv4 Net Mask	255.255.255.0	DHCP Disabled

	NAT Network ProviderNetwork1
	CIDR	203.0.113.0/24		DHCP Disabled

	NAT Network NatNetwork1
	CIDR	10.10.10.0/24		DHCP Enabled

	Network Interfaces

	Interface	Network	OS Name	Config Type	IP Addr	Netmask	Gateway	DNS Server	VirtualBox Network Name
	Adapter 1	Management	eth0	static	10.0.0.11	255.255.255.0	10.0.0.1	8.8.8.8	Host Only Adapter #2
	Adapter 2	Provider	eth1	manual	---	---	---	---	NAT Network ProviderNetwork1		Promiscuous Mode: Allow All
	Adapter 3	Internet	wlan0	NetworkManager	DHCP	DHCP	DHCP	DHCP	NAT Network NatNetwork1


	Operating System

	Name	Ubuntu Server 16.04 LTS
	Link	https://www.ubuntu.com/download/server


	Operating System Installation Options
				Recommended		Actual
	1. Language			English		English
	2. Hit F4 to choose 'Modes'			Install a Minimal Virtual Machine		Install a Minimal Virtual Machine
	3. Press Enter to 'Install Ubuntu Server'
	4. Choose Language			English-English		English-English
	5. Select your location 			United States		United States
	6. Detect keyboard layout?			No		No
	7. Keyboard layout			English (US)		English (US)
	8. Primary network interface			enp0s3		enp0s3
	9. Network configration method			Configure network manualy		Configure Network manualy
	10. IP address			10.0.0.11		10.0.0.11
	11. Netmask			255.255.255.0		255.255.255.0
	12. Gateway			<nothing>		<nothing>
	13. Name server address			8.8.8.8		8.8.8.8
	14. Hostname			controller		controller
	15. Domain name
	16. Full name of the new user					kris
	17. Username for your account					kris
	18. Choose password for the new user					openstack
	19. Encrypt your home directory?					no
	20. Select your time zone					Eastern
	21. Partitioning method			use entire disk and set up LVM		use entire disk and set up LVM
	22. HTTP Proxy					none
	23. How to manage upgrades?			No automatic updates		No automatic updates
	24. Choose software to install			OpenSSH Server		OpenSSH Server
	25. Install GRUB?			Yes		Yes


	Configure Security, Networking, Install Linux Utilities

	Configure 'sudo' access for 		kris
	sudo su
	visudo
	add following line at the bottom of the file:
	kris ALL=(ALL) NOPASSWD:ALL
	save, exit and run sudo su again to test

	Edit /etc/hosts
	Remove 127.0.1.1 controller, if present
	Make sure following lines are present:
	10.0.0.11 controller
	10.0.0.31 compute1
	10.0.0.41 block1

	Edit /etc/default/grub to include:
	GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"
	Run command:
	update-grub
	reboot

	Enable Network Interfaces
	sudo su
	Edit /etc/network/interfaces
	Make sure following Interfaces definitions are present:

	auto eth0
	iface eth0 inet static
	  address 10.0.0.11
	  netmask 255.255.255.0
	  dns-nameservers 8.8.8.8
	auto eth1
	iface eth1 inet manual
	  up ip link set dev eth1 up
	  down ip link set dev eth1 down
	auto eth2
	iface eth2 inet dhcp

	Reboot the system
	Run 'ifconfig' as superuser to verify settings.
	Verify connectivity to other hosts, once configured
	ping -c 3 openstack.org
	ping -c 3 compute1
	ping -c 3 block1

	Install basic Linux Utilities
	Run following commands:
	sudo su
	apt update
	apt install vim glances curl
	apt upgrade -y

	-----------------------------------------------------------------------------------------------------------

	Install and Configure Network Time Protocol

	Install and Configure Components

	sudo su
	apt install chrony

	Edit /etc/chrony/chrony.conf:
	set server to your Orgaznization's NTP Server, if you have one
	set allow to 10.0.0.0/24
	save and quit
	Restart chrony service:
	service chrony restart

	Verify:
	chronyc sources

----------------------------------------------------------------------------------------------------------------------------

	Install Basic OpenStack Packages

	sudo su
	apt install software-properties-common
	add-apt-repository cloud-archive:pike
	apt update && apt dist-upgrade
	reboot
	apt install python-openstackclient

----------------------------------------------------------------------------------------------------------------------------

	SQL Database - MariaDB

	Install and Configure Packages
	sudo su
	apt install mariadb-server python-pymysql

	Create and edit MariaDB configuration file: /etc/mysql/mariadb.conf.d/99-openstack.cnf
	Put following 7 lines in the file:
	[mysqld]
	bind-address = 10.0.0.11
	default-storage-engine = innodb
	innodb_file_per_table = on
	max_connections = 4096
	collation-server = utf8_general_ci
	character-set-server = utf8

	Restart MariaDB service:
	service mysql restart

	Secure the Database Service:
	mysql_secure_installation

----------------------------------------------------------------------------------------------------------------------------

	Message Queue - RabbitMQ

	Install and Configure Packages:
	sudo su
	apt install rabbitmq-server

	Add openstack user:
	rabbitmqctl add_user openstack openstack

	Configure permissions for openstack user:
	rabbitmqctl set_permissions openstack ".*" ".*" ".*"

----------------------------------------------------------------------------------------------------------------------------

	Memcached

	Install and Configure Packages:
	sudo su
	apt install memcached python-memcache

	Edit /etc/memcached.conf to define IP address:
	-l 10.0.0.11

	Restart Memcached Service:
	service memcached restart

----------------------------------------------------------------------------------------------------------------------------

	Etcd

	Create etcd User and directories:
	sudo su
	groupadd --system etcd
	useradd --home-dir "/var/lib/etcd" --system --shell /bin/false -g etcd etcd
	mkdir -p /etc/etcd
	chown etcd:etcd /etc/etcd
	mkdir -p /var/lib/etcd
	chown etcd:etcd /var/lib/etcd

	Download and install etcd tarball
	ETCD_VER=v3.2.7
	rm -rf /tmp/etcd && mkdir -p /tmp/etcd
	curl -L https://github.com/coreos/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
	tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd --strip-components=1
	cp /tmp/etcd/etcd /usr/bin/etcd
	cp /tmp/etcd/etcdctl /usr/bin/etcdctl

	Create and edit the /etc/etcd/etcd.conf.yml file
	vim /etc/etcd/etcd.conf.yml
	and put following 9 lines in it:
	name: controller
	data-dir: /var/lib/etcd
	initial-cluster-state: 'new'
	initial-cluster-token: 'etcd-cluster-01'
	initial-cluster: controller=http://10.0.0.11:2380
	initial-advertise-peer-urls: http://10.0.0.11:2380
	advertise-client-urls: http://10.0.0.11:2379
	listen-peer-urls: http://0.0.0.0:2380
	listen-client-urls: http://10.0.0.11:2379

	Create and edit /lib/systemd/system/etcd.service file
	vim /lib/systemd/system/etcd.service
	and put following 13 lines in it:
	[Unit]
	After=network.target
	Description=etcd - highly-available key value store

	[Service]
	LimitNOFILE=65536
	Restart=on-failure
	Type=notify
	ExecStart=/usr/bin/etcd --config-file /etc/etcd/etcd.conf.yml
	User=etcd

	[Install]
	WantedBy=multi-user.target

	Enable and start etcd Service:
	systemctl enable etcd
	systemctl start etcd

----------------------------------------------------------------------------------------------------------------------------


	Install Keystone - Identity Management

	Configure SQL Database for Keystone:
	Run these commands:
	sudo su
	mysql
	CREATE DATABASE keystone;
	GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'openstack';
	EXIT;

	Install and Configure Packages:
	Run these commands:
	sudo su
	# Install required packages + crudini to edit .conf files
	apt install keystone apache2 libapache2-mod-wsgi crudini -y
	# Configure Keystone database access, as set above
	crudini --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:openstack@controller/keystone
	# Set Fernet Token Provider
	crudini --set /etc/keystone/keystone.conf token provider fernet
	# Populate Identity Service Database
	su -s /bin/sh -c "keystone-manage db_sync" keystone
	# Initialize Fernet Repositories
	keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
	keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
	# Bootstrap Identity Service
	keystone-manage bootstrap --bootstrap-password openstack --bootstrap-admin-url http://controller:35357/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne

	Configure Apache Server:
	Edit /etc/apache2/apache2.conf and add following line:
	ServerName controller

	Restart the apache2 service
	service apache2 restart

	Configure OpenStack Client Environment Scripts
	Create admin-openrc Script (in Primary User's Home Directory, for example)
	Insert following lines:
	export OS_PROJECT_DOMAIN_NAME=Default
	export OS_USER_DOMAIN_NAME=Default
	export OS_PROJECT_NAME=admin
	export OS_USERNAME=admin
	export OS_PASSWORD=openstack
	export OS_AUTH_URL=http://controller:35357/v3
	export OS_IDENTITY_API_VERSION=3
	export OS_IMAGE_API_VERSION=2

	Create demo-openrc Script
	Insert following lines:
	export OS_PROJECT_DOMAIN_NAME=Default
	export OS_USER_DOMAIN_NAME=Default
	export OS_PROJECT_NAME=demo
	export OS_USERNAME=demo
	export OS_PASSWORD=openstack
	export OS_AUTH_URL=http://controller:5000/v3
	export OS_IDENTITY_API_VERSION=3
	export OS_IMAGE_API_VERSION=2

	Verify Keystone operation
	Run following commands:

	. admin-openrc
	openstack token issue

	Create Projects, Users and Roles
	Run following commands:

	. admin-openrc
	# Create a service Project
	openstack project create --domain default --description "Service Project" service
	# Create a demo Project
	openstack project create --domain default --description "Demo Project" demo
	# Create a demo User
	openstack user create --domain default --password "&DEMO_PASS&" demo"
	# Create a user Role
	openstack role create user
	# Add the user role to User demo in Project demo
	openstack role add --project demo --user demo user

	Verify User demo
	Run following commands:
	. demo-openrc
	openstack token issue

----------------------------------------------------------------------------------------------------------------------------


	Install Glance - Image Service

	Configure SQL Database for Glance
	Run following commands:

	sudo su
	mysql
	CREATE DATABASE glance;
	GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'openstack';
	EXIT;

	Create glance User
	. admin-openrc
	openstack user create --domain default --password "&GLANCE_PASS&" glance

	Add admin role to User glance in Project service
	openstack role add --project service --user glance admin

	Create glance Service
	openstack service create --name glance --description "OpenStack Image" image

	Create glance Service Endpoints
	openstack endpoint create --region RegionOne image public http://controller:9292
	openstack endpoint create --region RegionOne image internal http://controller:9292
	openstack endpoint create --region RegionOne image admin http://controller:9292

	Install and Configure Packages
	Run following commands:

	apt update -y
	apt install glance -y

	Configure /etc/glance/glance-api.conf Parameters
	Run following commands:
	# Configure database access for glance
	crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:openstack@controller/glance
	# Configure Identity Service access
	crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://controller:5000
	crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://controller:35357
	crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers controller:11211
	crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
	crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
	crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
	crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
	crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
	crudini --set /etc/glance/glance-api.conf keystone_authtoken password openstack
	crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
	# Configure Glance to store Images on Local Filesystem
	crudini --set /etc/glance/glance-api.conf glance_store stores "file,http"
	crudini --set /etc/glance/glance-api.conf glance_store default_store file
	crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/

	Configure /etc/glance/glance-registry.conf Parameters
	Run following commands:
	# Configure database access for glance
	crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:openstack@controller/glance
	# Configure Identity Service access
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://controller:5000
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://controller:35357
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers controller:11211
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken username glance
	crudini --set /etc/glance/glance-registry.conf keystone_authtoken password openstack
	crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

	Populate the Image Service Database
	Run following commands:
	su -s /bin/sh -c "glance-manage db_sync" glance

	Restart glance Services
	service glance-registry restart
	service glance-api restart

	Verify Glance Operation
	Run following commands:

	. admin-openrc
	wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
	openstack image create cirros3.5 --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
	openstack image list

	Download Cloud Images:		https://docs.openstack.org/image-guide/obtain-images.html

----------------------------------------------------------------------------------------------------------------------------

	Install & Configure Nova (Compute Service) Controller

	Configure SQL Databases for Nova
	Run following commands:

	sudo su
	mysql
	CREATE DATABASE nova_api;
	CREATE DATABASE nova;
	CREATE DATABASE nova_cell0;
	GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'openstack';

	Create Compute Service User and add admin role in service Project
	Run following commands:

	. admin-openrc
	openstack user create --domain default --password openstack nova
	openstack role add --project service --user nova admin

	Create Compute Service & Endpoints
	Run following commands:

	. admin-openrc
	openstack service create --name nova --description "OpenStack Compute" compute
	openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
	openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
	openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1

	Create Placement Service User and add admin role in service Project
	Run following commands:

	. admin-openrc
	openstack user create --domain default --password openstack placement
	openstack role add --project service --user placement admin

	Create Placement Service & Endpoints
	Run following commands:

	. admin-openrc
	openstack service create --name placement --description "Placement API" placement
	openstack endpoint create --region RegionOne placement public http://controller:8778
	openstack endpoint create --region RegionOne placement internal http://controller:8778
	openstack endpoint create --region RegionOne placement admin http://controller:8778

	Install Nova Controller Packages
	Run following commands:

	sudo su
	apt install -y nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api

	Configure MySQL & RabbitMQ parameters in /etc/nova/nova.conf
	Run following commands:

	crudini --set /etc/nova/nova.conf api_database connection mysql+pymysql://nova:openstack@controller/nova_api
	crudini --set /etc/nova/nova.conf database connection mysql+pymysql://nova:openstack@controller/nova
	crudini --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:openstack@controller

	Configure Identity Service access
	Run following commands:

	crudini --set /etc/nova/nova.conf api auth_strategy keystone
	crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000
	crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://controller:35357
	crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers controller:11211
	crudini --set /etc/nova/nova.conf keystone_authtoken auth_type password
	crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name default
	crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name default
	crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
	crudini --set /etc/nova/nova.conf keystone_authtoken username nova
	crudini --set /etc/nova/nova.conf keystone_authtoken password openstack

	Configure support for Networking Service
	Run following commands:

	crudini --set /etc/nova/nova.conf DEFAULT my_ip 10.0.0.11
	crudini --set /etc/nova/nova.conf DEFAULT use _neutron True
	crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

	Configure vnc proxy on Controller Node
	Run following commands:

	crudini --set /etc/nova/nova.conf vnc enabled True
	crudini --set /etc/nova/nova.conf vnc vncserver_listen 10.0.0.11
	crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address 10.0.0.11

	Configure Glance location
	Run following command:

	crudini --set /etc/nova/nova.conf glance api_servers http://controller:9292

	Configure Lock Path for Oslo Concurrency
	Run following command:

	crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

	Configure Placement API
	Run following commands:

	crudini --set /etc/nova/nova.conf placement os_region_name RegionOne
	crudini --set /etc/nova/nova.conf placement project_domain_name Default
	crudini --set /etc/nova/nova.conf placement project_name service
	crudini --set /etc/nova/nova.conf placement auth_type password
	crudini --set /etc/nova/nova.conf placement user_domain_name Default
	crudini --set /etc/nova/nova.conf placement auth_url http://controller:35357/v3
	crudini --set /etc/nova/nova.conf placement username placement
	crudini --set /etc/nova/nova.conf placement password openstack

	Remove log_dir parameter in DEFAULT section
	Run following command:

	crudini --del /etc/nova/nova.conf DEFAULT log_dir

	Populate nova_api Database
	Run following commands:

	sudo su
	su -s /bin/sh -c "nova-manage api_db sync" nova

	Register cell0 Database
	Run following command:

	su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova

	Create cell1 Cell
	Run following command:

	su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova

	Populate nova Database
	Run following command:

	su -s /bin/sh -c "nova-manage db sync" nova

	Verify configuration of Cells
	Run following command:

	nova-manage cell_v2 list_cells

	Restart Services
	Run following commands:

	service nova-api restart
	service nova-consoleauth restart
	service nova-scheduler restart
	service nova-conductor restart
	service nova-novncproxy restart

	Install and Configure Nova on Compute Node(s)

	Discover Compute Nodes
	Run following command:

	su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova

	Verify Compute Service Installation
	Run following commands:

	. admin-openrc
	openstack compute service list
	openstack catalog list
	openstack image list
	nova-status upgrade check


	Install Neutron (Network Service) on Controller Node

	Create Neutron SQL Database
	Run following commands:

	sudo su
	mysql
	CREATE DATABASE neutron;
	GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'openstack';
	EXIT;

	Create neutron User and add admin Role in service Project
	Run following commands:

	. admin-openrc
	openstack user create --domain default --password openstack neutron
	openstack role add --project service --user neutron admin

	Create Neutron Service and Endpoints
	Run following commands:

	openstack service create --name neutron --description "OpenStack Networking" network
	openstack endpoint create --region RegionOne network public http://controller:9696
	openstack endpoint create --region RegionOne network internal http://controller:9696
	openstack endpoint create --region RegionOne network admin http://controller:9696

	Install Neutron Packages
	Run following commands:

	sudo su
	apt install -y neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent  neutron-metadata-agent

	Configure SQL Database and RabbitMQ access for Neutron
	Run following commands:

	crudini --set /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:openstack@controller/neutron
	crudini --set /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:openstack@controller

	Enable the Modular Layer 2 (ML2) plug-in, router service, and overlapping IP addresses
	Run following commands:

	crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
	crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
	crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips true

	Configure Identity Service access
	Run following commands:

	crudini --set /etc/neutron/neutron.conf api auth_strategy keystone
	crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000
	crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller:35357
	crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers controller:11211
	crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
	crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
	crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
	crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name service
	crudini --set /etc/neutron/neutron.conf keystone_authtoken username neutron
	crudini --set /etc/neutron/neutron.conf keystone_authtoken password openstack

	"Configure Networking to notify Compute of network topology changes
"
	Run following commands:

	crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes true
	crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes true

	Configure Nova access
	Run following commands:

	crudini --set /etc/neutron/neutron.conf nova auth_url http://controller:35357
	crudini --set /etc/neutron/neutron.conf nova auth_type password
	crudini --set /etc/neutron/neutron.conf nova project_domain_name default
	crudini --set /etc/neutron/neutron.conf nova user_domain_name default
	crudini --set /etc/neutron/neutron.conf nova region_name RegionOne
	crudini --set /etc/neutron/neutron.conf nova project_name service
	crudini --set /etc/neutron/neutron.conf nova username nova
	crudini --set /etc/neutron/neutron.conf nova password openstack

	Configure ML2 Plugin
	Run following commands:

	# Enable flat, VLAN and VXLAN Networks
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,vxlan
	# Enable VXLAN Self-service Networks
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
	# Enable Linux Bridge and L2Population mechanisms
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge,l2population
	# Enable Port Security Extenstion Driver
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
	# Configure provider Virtual Network as flat Network
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks provider
	# Configure VXLAN Network Identifier Range for Self-service Networks
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
	# Enable ipset to increase efficiency of Security Group Rules
	crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset true

	Configure the Linux Bridge Agent
	Run following commands:

	# Configure provider Virtual Network mapping to Physical Interface
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:eth1
	# Enable VXLAN for Self-service Networks, configure IP address of the Management Interface handling VXLAN traffic
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan true
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip 10.0.0.11
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population true
	# Enable security groups and configure the Linux bridge iptables firewall driver
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group true
	crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

	Configure the Layer-3 Agent
	Run following command:

	crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver linuxbridge

	Configure the DHCP Agent
	Run following commands:

	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver linuxbridge
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
	crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true

	Configure Metadata Agent
	Run following commands:

	crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host controller
	crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret openstack

	Configure Compute Service to use Neutron
	Run following commands:

	crudini --set /etc/nova/nova.conf neutron url http://controller:9696
	crudini --set /etc/nova/nova.conf neutron auth_url http://controller:35357
	crudini --set /etc/nova/nova.conf neutron auth_type password
	crudini --set /etc/nova/nova.conf neutron project_domain_name default
	crudini --set /etc/nova/nova.conf neutron user_domain_name default
	crudini --set /etc/nova/nova.conf neutron region_name RegionOne
	crudini --set /etc/nova/nova.conf neutron project_name service
	crudini --set /etc/nova/nova.conf neutron username neutron
	crudini --set /etc/nova/nova.conf neutron password openstack
	crudini --set /etc/nova/nova.conf neutron service_metadata_proxy true
	crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret openstack

	Populate Neutron Database
	Run following Command:

	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

	Restart the Compute API Service
	Run following command:

	service nova-api restart

	Restart Networking Services
	Run following Commands:

	service neutron-server restart
	service neutron-linuxbridge-agent restart
	service neutron-dhcp-agent restart
	service neutron-metadata-agent restart
	service neutron-l3-agent restart

	Install Neutron on Compute Nodes

	Verify Installation
	Run following commands:

	. admin-openrc
	openstack network agent list


	Install Cinder - Block Storage Service on block1 Node


	Install Cinder Block Storage Service on Controller Node

	Create Cinder Database
	Run following commands:

	sudo su
	mysql
	CREATE DATABASE cinder;
	GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'openstack';
	GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'openstack';
	EXIT;

	Create cinder User and Add admin Role in service Project
	Run following commands:

	. admin-openrc
	openstack user create --domain default --password openstack cinder
	openstack role add --project service --user cinder admin

	Create cinderv2 and cinderv3 Services and their Endpoints
	Run following commands:

	openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
	openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
	openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s

	Install Packages
	Run following command:

	apt install -y cinder-api cinder-scheduler

	Configure Database and RabbitMQ Access
	Run following commands:

	crudini --set /etc/cinder/cinder.conf database connection mysql+pymysql://cinder:openstack@controller/cinder
	crudini --set /etc/cinder/cinder.conf DEFAULT transport_url rabbit://openstack:openstack@controller

	Configure Identity Service Access
	Run following commands:

	crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
	crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://controller:5000
	crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://controller:35357
	crudini --set /etc/cinder/cinder.conf keystone_authtoken memcached_servers controller:11211
	crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_type password
	crudini --set /etc/cinder/cinder.conf keystone_authtoken project_domain_name default
	crudini --set /etc/cinder/cinder.conf keystone_authtoken user_domain_name default
	crudini --set /etc/cinder/cinder.conf keystone_authtoken project_name service
	crudini --set /etc/cinder/cinder.conf keystone_authtoken username cinder
	crudini --set /etc/cinder/cinder.conf keystone_authtoken password openstack

	Configure my_ip Parameter and Lock Path
	Run following commands:

	crudini --set /etc/cinder/cinder.conf DEFAULT my_ip 10.0.0.11
	crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp

	Populate Block Storage Database
	Run following command:

	su -s /bin/sh -c "cinder-manage db sync" cinder

	Configure Compute Service to use Cinder
	Run following command:

	crudini --set /etc/nova/nova.conf cinder os_region_name RegionOne

	Restart Services
	Run following commands:

	service nova-api restart
	service cinder-scheduler restart
	service apache2 restart

	Verify Cinder Operation
	Run following commands:

	. admin-openrc
	openstack volume service list


	Install Horizon Dashboard

	Install Packages
	Run following commands:

	sudo su
	apt install -y openstack-dashboard

	Edit /etc/openstack-dashboard/local_settings.py to include following settings:

	OPENSTACK_HOST = "controller"

	SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

	CACHES = {
	    'default': {
	         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
	         'LOCATION': 'controller:11211',
	    }
	}

	OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST

	OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True

	OPENSTACK_API_VERSIONS = {
	    "identity": 3,
	    "image": 2,
	    "volume": 2,
	}

	OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"

	OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"

	Edit /etc/apache2/conf-available/openstack-dashboard.conf to include following line:

	WSGIApplicationGroup %{GLOBAL}

	Reload Web Server Configuration
	Run following command:

	service apache2 reload

	Verify Horizon Operation by pointing Web Browser to

	http://10.0.0.11/horizon
