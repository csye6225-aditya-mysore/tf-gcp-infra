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

resource "google_compute_network" "east1-vpc" {
  name                            = "east1-vpc-network"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "webapp" {
  name          = "webapp-subnet"
  network       = google_compute_network.east1-vpc.self_link
  ip_cidr_range = "10.1.1.0/24"
  region        = var.region
  depends_on    = [google_compute_network.east1-vpc]
}

resource "google_compute_subnetwork" "db" {
  name          = "db-subnet"
  network       = google_compute_network.east1-vpc.self_link
  ip_cidr_range = "10.1.0.0/24"
  region        = var.region
  depends_on    = [google_compute_network.east1-vpc]
}


resource "google_compute_route" "public_route" {
  name             = "public-route-for-webapp"
  network          = google_compute_network.east1-vpc.id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  depends_on = [ google_compute_subnetwork.webapp ]

  tags = [
    "webapp-subnet"
  ]
}