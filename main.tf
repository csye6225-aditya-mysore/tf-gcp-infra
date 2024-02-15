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
  name                            = "${var.vpc_name}-${count.index}"
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
  ip_cidr_range = cidrsubnet(var.cidr-range, 4, count.index + var.number-of-subnets)
  region        = var.region
}


resource "google_compute_route" "public_route_for_webapp" {
  name             = "${var.public-route-name}-${count.index}"
  count            = var.vpc-count
  network          = google_compute_network.csye-vpc[count.index].self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"

  tags = [
    google_compute_subnetwork.webapp[count.index].name
  ]
}