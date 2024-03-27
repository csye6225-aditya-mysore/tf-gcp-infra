terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.15.0"
    }
  }
}

provider "google-beta" {
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
  project = var.project_id
  count         = var.vpc-count
  network       = google_compute_network.csye-vpc[count.index].id
  ip_cidr_range = cidrsubnet(var.cidr-range, 4, count.index)
  region        = var.region
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "db" {
  name          = "${var.db-subnet-name}-${count.index}"
  project = var.project_id
  count         = var.vpc-count
  network       = google_compute_network.csye-vpc[count.index].id
  ip_cidr_range = cidrsubnet(var.cidr-range, 4, count.index + var.vpc-count)
  region        = var.region
}


resource "google_compute_route" "public_route_for_webapp" {
  name             = "${var.public-route-name}-${count.index}"
  count            = var.vpc-count
  project = var.project_id
  network          = google_compute_network.csye-vpc[count.index].id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_firewall" "webapp_ingress_firewall" {
  name    = "webapp-ingress-firewall"
  count = var.vpc-count
  project = var.project_id
  network = google_compute_network.csye-vpc[count.index].id
  priority = var.allow-firewall-priority

  allow {
    protocol = var.traffic-type
    ports    = var.allowed-ports-to-instance
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
  project = var.project_id
  network = google_compute_network.csye-vpc[count.index].id
  priority = var.deny-firewall-priority

  deny {
    protocol = var.traffic-type
  }

  source_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = [
    "webapp"
  ]
}

# resource "google_compute_firewall" "webapp_out_firewall" {
#   name    = "webapp-out-firewall"
#   count = var.vpc-count
#   direction = "EGRESS"
#   network = google_compute_network.csye-vpc[count.index].id
#   priority = var.allow-firewall-priority

#   allow {
#     protocol = var.traffic-type
#   }

#   destination_ranges = [
#     "0.0.0.0/0"
#   ]

#   target_tags = [
#     "webapp"
#   ]
# }

# resource "google_project_service" "project" {
#   project = var.project_id
#   service = "servicenetworking.googleapis.com"
# }

# resource "google_compute_global_address" "private_ip_range_allocation" {
#   name = "ip-range-for-google"
#   project     = var.project_id
#   count = var.vpc-count
#   address_type = "INTERNAL"
#   purpose = "VPC_PEERING"
#   prefix_length = 16
#   network = google_compute_network.csye-vpc[0].self_link
# }

resource "google_compute_address" "private_ip_address" {
  name = "ip-range-for-google"
  project     = var.project_id
  region = var.region
  address_type = "INTERNAL"
  address      = var.private-ip-address
  subnetwork = google_compute_subnetwork.webapp[0].self_link

  depends_on = [ 
    google_compute_subnetwork.webapp[0]
  ]
}

data "google_sql_database_instance" "database_instance_data" {
  project = var.project_id
  name = resource.google_sql_database_instance.database_instance.name
  depends_on = [ 
    google_sql_database_instance.database_instance
   ]
}

resource "google_compute_forwarding_rule" "default" {
  name                  = "psc-forwarding-rule"
  project     = var.project_id
  region                = var.region
  network               = google_compute_network.csye-vpc[0].self_link
  ip_address            = google_compute_address.private_ip_address.self_link
  load_balancing_scheme = ""
  target                = data.google_sql_database_instance.database_instance_data.psc_service_attachment_link

  depends_on = [ 
    google_compute_network.csye-vpc[0],
    google_compute_address.private_ip_address
   ]
}

# resource "google_service_networking_connection" "vpc_peering_google_services" {
#   count = var.vpc-count
#   network = google_compute_network.csye-vpc[count.index].self_link
#   service = "servicenetworking.googleapis.com"
#   reserved_peering_ranges = [google_compute_global_address.private_ip_range_allocation[0].name]
#   deletion_policy = "ABANDON"
# }

# COMPUTE RESOURCES
resource "google_compute_instance" "new_instance" {
  name = var.compute-instance-name
  project     = var.project_id
  machine_type = var.compute-machine-type
  zone = var.zone
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
    subnetwork = google_compute_subnetwork.webapp[0].self_link
  }

  metadata_startup_script = <<-EOT
  #!/bin/bash
  echo "Hello, World! This is a startup script."
  echo "Started with startup script"
  if ! test [-f /opt/webapp/.env]; then
    echo "DATABASE_NAME=${google_sql_database.sql_database.name}" > /opt/webapp/.env
    echo "USERNAME=${google_sql_user.sql_user.name}" >> /opt/webapp/.env
    echo "PASSWORD=${google_sql_user.sql_user.password}" >> /opt/webapp/.env
    echo "DATABASE_HOST=${google_compute_address.private_ip_address.address}" >> /opt/webapp/.env
    echo "PUBSUB=${google_pubsub_topic.verify_email_1.name}" >> /opt/webapp/.env
    sudo chown csye6225:csye6225 /opt/webapp/.env
  fi
  sudo systemctl daemon-reload
  sudo systemctl enable webapp.service
  sudo systemctl start webapp.service
EOT
  tags = ["webapp"]

  service_account {
    email = google_service_account.instance_service_account.email
    scopes = [ "cloud-platform" ]
  }

  depends_on = [ 
    google_compute_network.csye-vpc[0],
    google_sql_database_instance.database_instance, 
    google_sql_database.sql_database,
    google_sql_user.sql_user, 
    google_compute_address.private_ip_address,
    google_service_account.instance_service_account,
    google_pubsub_topic.verify_email_1
    ]
}


# DATABASE RESOURCES

resource "google_sql_database_instance" "database_instance" {
  name = "newdb"
  project = var.project_id
  deletion_protection = var.database-deletion-protection
  database_version = var.database-version
  region = var.region
  settings {
    disk_type = "PD_SSD"
    disk_size = var.database-disk-size
    tier = var.database-tier
    ip_configuration {
      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]
      }
      ipv4_enabled = false
    }
    availability_type = "REGIONAL"
  }

  # depends_on = [ google_service_networking_connection.vpc_peering_google_services[0] ]
}

resource "google_sql_database" "sql_database" {
  name = "webapp"
  project = var.project_id
  instance = google_sql_database_instance.database_instance.name
  depends_on = [ google_sql_database_instance.database_instance ]
  deletion_policy = "ABANDON"
}

resource "google_sql_user" "sql_user" {
  name = "webapp"
  project = var.project_id
  instance = google_sql_database_instance.database_instance.name
  password = random_password.sql_password.result
  depends_on = [ google_sql_database.sql_database ]
  deletion_policy = "ABANDON"
} 


# RANDOM Generators

resource "random_password" "sql_password" {
  length = 10
}

# SERVICE ACCOUNT
resource "google_service_account" "instance_service_account" {
  account_id = var.service-account-id
  display_name = var.service-account-display-name
  project = var.project_id
}

# IAM ROLE Bindings
resource "google_project_iam_binding" "logging_role_binding" {
  project = var.project_id
  role = "roles/logging.admin"

  members = [ 
    "serviceAccount:${google_service_account.instance_service_account.email}"
   ]

   depends_on = [ google_service_account.instance_service_account ]
}

resource "google_project_iam_binding" "monitoring_role_binding" {
  project = var.project_id
  role = "roles/monitoring.metricWriter"

  members = [ 
    "serviceAccount:${google_service_account.instance_service_account.email}"
   ]

   depends_on = [ google_service_account.instance_service_account ]
}

resource "google_pubsub_topic_iam_binding" "pubsub_binding" {
  project = var.project_id
  role = "roles/pubsub.publisher"
  topic = var.pubsub-topic-name
  members = [ 
    "serviceAccount:${google_service_account.instance_service_account.email}"
   ]

   depends_on = [ 
    google_service_account.instance_service_account,
    google_pubsub_topic.verify_email_1
     ]
}

resource "google_cloud_run_service_iam_binding" "cloudfunction_binding" {
  project = google_cloudfunctions2_function.function1.project
  location = google_cloudfunctions2_function.function1.location
  service = google_cloudfunctions2_function.function1.name
  role = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.instance_service_account.email}"
  ]

  depends_on = [ 
    google_service_account.instance_service_account,
    google_cloudfunctions2_function.function1
     ]
}

# DNS
resource "google_dns_record_set" "compute_instance_ip_record" {
  name = var.dns-name
  type = "A"
  ttl = 30
  project = var.project_id

  managed_zone = var.dns-managed-zone-name
  rrdatas = [ google_compute_instance.new_instance.network_interface[0].access_config[0].nat_ip ]
  depends_on = [ google_compute_instance.new_instance ]
}

# VPC Connector for serverless access

resource "google_vpc_access_connector" "connector" {
  name          = "vpc-con"
  ip_cidr_range = var.vpc-connector-ip-cidr
  project = var.project_id
  region = var.region
  network       = google_compute_network.csye-vpc[0].name
  min_instances = 2
  max_instances = 3
  depends_on = [ google_compute_network.csye-vpc[0] ]
}

# PubSub

resource "google_pubsub_topic" "verify_email_1" {
  name = var.pubsub-topic-name
  project = var.project_id
}

# Cloud function

resource "google_cloudfunctions2_function" "function1" {
  name = "example2"
  location = var.region
  description = "Function to send emails"
  project = var.project_id

  build_config {
    runtime = "nodejs20"
    entry_point = var.function-entry-point
    

    source {
      storage_source {
        bucket = var.bucket-name
        object = google_storage_bucket_object.function-object.name
      }
    }
  
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 0
    available_memory = "256M"
    timeout_seconds = 60
    ingress_settings = "ALLOW_ALL"
    service_account_email = google_service_account.instance_service_account.email

    environment_variables = {
      DATABASE_NAME = google_sql_database.sql_database.name,
      USERNAME = google_sql_user.sql_user.name,
      PASSWORD = google_sql_user.sql_user.password,
      DATABASE_HOST = google_compute_address.private_ip_address.address
    }

    vpc_connector = google_vpc_access_connector.connector.name
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.verify_email_1.id
    service_account_email = google_service_account.instance_service_account.email
  }

  depends_on = [ 
    google_vpc_access_connector.connector,
    google_pubsub_topic.verify_email_1,
    google_sql_database.sql_database,
    google_sql_user.sql_user,
    google_compute_address.private_ip_address,
    google_pubsub_topic_iam_binding.pubsub_binding,
    google_storage_bucket_object.function-object,
    google_service_account.instance_service_account
   ]
  
}

data "archive_file" "default" {
  type        = "zip"
  output_path = "/tmp/function-source.zip"
  source_dir  = "./serverless/"
}

resource "google_storage_bucket_object" "function-object" {
  name   = "function-source.zip"
  bucket = var.bucket-name
  source = data.archive_file.default.output_path # Add path to the zipped function source code
}