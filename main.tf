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

#NETWORK RESOURCES

resource "google_compute_network" "csye-vpc" {
  name                            = "${var.vpc-name}-${count.index}"
  project     = var.project_id
  count                           = var.vpc-count
  auto_create_subnetworks         = var.auto-create-subnets-boolean
  routing_mode                    = var.routing-mode
  delete_default_routes_on_create = var.delete-default-routes-on-create
}


resource "google_compute_subnetwork" "webapp" {
  name          = "${var.webapp-subnet-name}-${count.index}"
  count         = var.vpc-count
  network       = google_compute_network.csye-vpc[count.index].id
  ip_cidr_range = cidrsubnet(var.cidr-range, 4, count.index)
  region        = var.region
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "db" {
  name          = "${var.db-subnet-name}-${count.index}"
  count         = var.vpc-count
  network       = google_compute_network.csye-vpc[count.index].id
  ip_cidr_range = cidrsubnet(var.cidr-range, 4, count.index + var.vpc-count)
  region        = var.region
}


resource "google_compute_route" "public_route_for_webapp" {
  name             = "${var.public-route-name}-${count.index}"
  count            = var.vpc-count
  network          = google_compute_network.csye-vpc[count.index].id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_firewall" "webapp_ingress_firewall" {
  name    = "webapp-ingress-firewall"
  count = var.vpc-count
  network = google_compute_network.csye-vpc[count.index].id
  priority = var.allow-firewall-priority

  allow {
    protocol = var.traffic-type
    ports    = [var.app-port, "5432"]
  }

  source_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = [
    "webapp"
  ]
}

resource "google_compute_firewall" "webapp_ingress_firewall_2" {
  name    = "webapp-ingress-firewall-2"
  count = var.vpc-count
  network = google_compute_network.csye-vpc[count.index].id
  priority = var.deny-firewall-priority

  allow {
    protocol = var.traffic-type
  }

  source_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = [
    "webapp"
  ]
}

resource "google_compute_firewall" "webapp_out_firewall" {
  name    = "webapp-out-firewall"
  count = var.vpc-count
  direction = "EGRESS"
  network = google_compute_network.csye-vpc[count.index].id
  priority = var.allow-firewall-priority

  allow {
    protocol = var.traffic-type
  }

  destination_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = [
    "webapp"
  ]
}

# resource "google_project_service" "project" {
#   project = var.project_id
#   service = "servicenetworking.googleapis.com"
# }

resource "google_compute_global_address" "private_ip_range_allocation" {
  name = "ip-range-for-google"
  project     = var.project_id
  count = var.vpc-count
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  prefix_length = 24
  network = google_compute_network.csye-vpc[count.index].id
}

resource "google_service_networking_connection" "vpc_peering_google_services" {
  count = var.vpc-count
  network = google_compute_network.csye-vpc[count.index].id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range_allocation[count.index].name]
  deletion_policy = "ABANDON"
}

# COMPUTE RESOURCES
resource "google_compute_instance" "new_instance" {
  name = var.compute-instance-name
  # project     = var.project_id
  machine_type = var.compute-machine-type
  # zone = var.zone
  boot_disk {
    auto_delete = var.compute-disk-autodelete
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
    network = google_compute_network.csye-vpc[0].name
    subnetwork = google_compute_subnetwork.webapp[0].name
  }

  # scheduling {
  #   automatic_restart   = var.compute-instance-automatic-restart
  #   on_host_maintenance = var.on-host-maintenance
  #   preemptible         = var.preemptible
  #   provisioning_model  = var.provisioning-model
  # }

  tags = ["webapp"]
  depends_on = [ google_compute_network.csye-vpc[0] ]
}


# DATABASE RESOURCES

resource "google_sql_database_instance" "database_instance" {
  name = "dbnstance"
  deletion_protection = false
  database_version = "POSTGRES_15"
  region = var.region
  settings {
    disk_type = "PD_SSD"
    disk_size = 100
    tier = "db-custom-2-13312"
    ip_configuration {
      ipv4_enabled = true
      private_network = google_compute_network.csye-vpc[0].id
      enable_private_path_for_google_cloud_services = true
    }
    availability_type = "REGIONAL"
  }

  depends_on = [ google_service_networking_connection.vpc_peering_google_services[0] ]
}

resource "google_sql_database" "sql_database" {
  name = "mydatabase"
  instance = google_sql_database_instance.database_instance.id
  depends_on = [ google_sql_database_instance.database_instance ]
}

resource "google_sql_user" "sql_user" {
  name = "webapp"
  instance = google_sql_database_instance.database_instance.id
  password = "webapppass"
  depends_on = [ google_sql_database.sql_database ]
  deletion_policy = "ABANDON"
} 


# RANDOM Generators

resource "random_password" "sql_password" {
  length = 5
}
