# Crear red desarrollo-net
resource "openstack_networking_network_v2" "desarrollo_net" {
  name           = "desarrollo-net"
  admin_state_up = "true"
}

# Crear subred desarrollo-subnet
resource "openstack_networking_subnet_v2" "desarrollo_subnet" {
  name       = "desarrollo-subnet"
  network_id = openstack_networking_network_v2.desarrollo_net.id
  cidr       = "10.2.0.0/24"
  ip_version = 4
  dns_nameservers = ["150.214.156.2", "8.8.8.8"]
}

# Crear router desarrollo-router
data "openstack_networking_network_v2" "public" {
  name = "public1"
}

resource "openstack_networking_router_v2" "desarrollo_router" {
  name                = "desarrollo-router"
  admin_state_up      = "true"
  external_network_id = data.openstack_networking_network_v2.public.id
}

# Conectar el router a la subred
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.desarrollo_router.id
  subnet_id = openstack_networking_subnet_v2.desarrollo_subnet.id
}

#Crear nodo tf_vm
#Creación de un recurso instancia (máquina virtual) en OpenStack. El objeto recurso creado es asignado a la variable tf_vm.
resource "openstack_compute_instance_v2" "tf_vm" {
  name              = "tf_vm"
  image_name        = "ubuntu24.04"
  availability_zone = "nova"
  flavor_name       = "m1.large"
  key_pair          = var.openstack_keypair
  security_groups   = var.openstack_security_groups
  network {
    #Red a la que se conectará la instancia creada. Usamos una variable de entrada almacenada en variables.tf con el nombre de la red.
    uuid = openstack_networking_network_v2.desarrollo_net.id

  }
  user_data = file("install_mysql.sh")
}

#Crear nodo appserver
resource "openstack_compute_instance_v2" "appserver" {
  name              = "appserver"
  image_name        = "ubuntu24.04"
  availability_zone = "nova"
  flavor_name       = "m1.medium"
  key_pair          = var.openstack_keypair
  security_groups = var.openstack_security_groups

  network {
    uuid = openstack_networking_network_v2.desarrollo_net.id
  }

    user_data = templatefile("${path.module}/install_appserver.tpl", { mysql_ip = openstack_compute_instance_v2.tf_vm.network.0.fixed_ip_v4 })

  depends_on = [openstack_compute_instance_v2.tf_vm]

}

#Creación de un recurso dirección IP flotante. El objeto recurso creado es asignado a la variable tf_vm_ip.
resource "openstack_networking_floatingip_v2" "tf_vm_ip" {
  pool = "public1"
}

# Crear floating IP para appserver
resource "openstack_networking_floatingip_v2" "appserver_ip" {
  pool = "public1"
}

#Asociación de la IP flotante a la instancia
#Acceso a la dirección del recurso IP flotante creado
#Acceso al id la instancia creada
resource "openstack_compute_floatingip_associate_v2" "tf_vm_ip" {
  floating_ip = openstack_networking_floatingip_v2.tf_vm_ip.address
  instance_id = openstack_compute_instance_v2.tf_vm.id
}

#Acceso a la dirección del recurso IP flotante creado
#Esperar a que esté creado el recurso de la IP flotante
output tf_vm_Floating_IP {
  value      = openstack_networking_floatingip_v2.tf_vm_ip.address
  depends_on = [openstack_networking_floatingip_v2.tf_vm_ip]
}

resource "openstack_compute_floatingip_associate_v2" "appserver_ip" {
  floating_ip = openstack_networking_floatingip_v2.appserver_ip.address
  instance_id = openstack_compute_instance_v2.appserver.id
}

output appserver_Floating_IP {
  value      = openstack_networking_floatingip_v2.appserver_ip.address
  depends_on = [openstack_networking_floatingip_v2.appserver_ip]
}

#Crear volumen 1GB
resource "openstack_blockstorage_volume_v3" "tf_vol" {
  name        = "tf_vol"
  description = "first test volume"
  size        = 1
}

#Adjuntar volumen a la instancia
resource "openstack_compute_volume_attach_v2" "va_1" {
  instance_id = "${openstack_compute_instance_v2.tf_vm.id}"
  volume_id   = "${openstack_blockstorage_volume_v3.tf_vol.id}"
}