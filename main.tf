terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.15.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

resource "google_compute_network" "csye-vpc" {
  name                            = "${var.vpc-name}-${count.index}"
  count                           = var.vpc-count
  auto_create_subnetworks         = var.auto-create-subnets-boolean
  routing_mode                    = var.routing-mode
  delete_default_routes_on_create = var.delete-default-routes-on-create
}


resource "google_compute_subnetwork" "webapp" {
  name          = "${var.webapp-subnet-name}-${count.index}"
  count         = var.vpc-count
  network       = google_compute_network.csye-vpc[count.index].self_link
  ip_cidr_range = cidrsubnet(var.cidr-range, 4, count.index)
  region        = var.region
}

resource "google_compute_subnetwork" "db" {
  name          = "${var.db-subnet-name}-${count.index}"
  count         = var.vpc-count
  network       = google_compute_network.csye-vpc[count.index].self_link
  ip_cidr_range = cidrsubnet(var.cidr-range, 4, count.index + var.vpc-count)
  region        = var.region
}


resource "google_compute_route" "public_route_for_webapp" {
  name             = "${var.public-route-name}-${count.index}"
  count            = var.vpc-count
  network          = google_compute_network.csye-vpc[count.index].self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_firewall" "webapp_ingress_firewall" {
  name    = "webapp-ingress-firewall"
  count = var.vpc-count
  network = google_compute_network.csye-vpc[count.index].name

  allow {
    protocol = "tcp"
    ports    = [var.app-port]
  }

  source_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = [
    "webapp"
  ]
}

resource "google_compute_instance" "new_instance" {
  name = var.compute-instance-name
  machine_type = var.compute-machine-type
  zone = var.zone
  boot_disk {
    auto_delete = true
    device_name = var.compute-instance-name

    initialize_params {
      image = var.compute-image
      size = var.compute-disk-size
      type = var.compute-instance-disk-type
    }

    mode = "READ_WRITE"
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    stack_type  = var.stack-type
    subnetwork = google_compute_subnetwork.webapp[0].name
  }

  scheduling {
    automatic_restart   = var.compute-instance-automatic-restart
    on_host_maintenance = var.on-host-maintenance
    preemptible         = var.preemptible
    provisioning_model  = var.provisioning-model
  }

  tags = ["webapp"]
  depends_on = [ google_compute_network.csye-vpc[0] ]
}