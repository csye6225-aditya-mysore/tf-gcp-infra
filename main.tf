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
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
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
    ports    = ["8000"]
  }

  source_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = [
    "webapp"
  ]
}

resource "google_compute_instance" "new_instance" {
  name = "my-instance"
  machine_type = "e2-micro"
  zone = var.zone
  boot_disk {
    auto_delete = true
    device_name = "my-instance"

    initialize_params {
      image = "projects/dev-aditya-mysore/global/images/practice-image-centos-8"
      size = 100
      type = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    stack_type  = "IPV4_ONLY"
    subnetwork = google_compute_subnetwork.webapp[0].name
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  tags = ["http-server", "webapp"]
  depends_on = [ google_compute_network.csye-vpc[0] ]
}