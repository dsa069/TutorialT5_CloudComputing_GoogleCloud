resource "google_compute_network" "vpc_network" {
  name = var.gcp-network
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "firewall-icmp" {
  name    = "terraform-allow-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "firewall-ssh" {
  name    = "terraform-allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# allow http traffic
resource "google_compute_firewall" "allow-http" {
  name    = "tf-fw-allow-http"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  target_tags   = ["http"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "firewall-internal" {
  name    = "terraform-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.128.0.0/20"]
}

#Crear subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "terraform-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

#Crear una IP estática reservada
resource "google_compute_address" "tf-vm-ip" {
  name = "ipv4-address-tf-vm"
}

resource "google_compute_instance" "tf-vm" {
  name         = "tf-vm"
  zone         = "us-central1-c"
  machine_type = "n1-standard-2"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  # Add SSH access to the Compute Engine instance
  metadata = {
    ssh-keys = "${var.gcp-username}:${file("~/.ssh/clave-gc.pub")}"
  }

  # Add http tag to the instance to identify it in the firewall rule
  tags = ["http"] 

  # Startup script
  metadata_startup_script = file("setup-docker.sh")

  network_interface {
    network    = var.gcp-network
    subnetwork = google_compute_subnetwork.subnet.name

    # Se comenta el access_config vacío (IP efímera) porque se usará una IP estática
    # access_config {}

    # Asignar la IP estática reservada creada anteriormente
    access_config {
      nat_ip = google_compute_address.tf-vm-ip.address
    }

  }
}

output "tf-vm-ip" {
  value      = google_compute_address.tf-vm-ip.address
  depends_on = [google_compute_instance.tf-vm]
}

resource "google_compute_disk" "tf-disk" {
  name = "tf-disk"
  type = "pd-ssd"
  size = 1
}

resource "google_compute_attached_disk" "attached-tf-disk" {
  disk     = google_compute_disk.tf-disk.id
  instance = google_compute_instance.tf-vm.id
}

output "tf-vm-internal-ip" {
  value      = google_compute_instance.tf-vm.network_interface.0.network_ip
  depends_on = [google_compute_instance.tf-vm]
}

# Output de IP efímera comentado porque ahora se usa la IP estática
# output "tf-vm-ephemeral-ip" {
#   value      = google_compute_instance.tf-vm.network_interface.0.access_config.0.nat_ip
#   depends_on = [google_compute_instance.tf-vm]
# }
