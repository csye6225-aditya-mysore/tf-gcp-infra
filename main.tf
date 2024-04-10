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

# SUBNETWORKS

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

resource "google_compute_subnetwork" "proxy_only_subnet" {
  name = "proxy-subnet-${count.index}"
  project = var.project_id
  count = var.vpc-count
  network       = google_compute_network.csye-vpc[count.index].id
  ip_cidr_range = var.proxy-subnet-cidr
  region = var.region
  purpose       = "REGIONAL_MANAGED_PROXY"
  role = "ACTIVE"
}


resource "google_compute_route" "public_route_for_webapp" {
  name             = "${var.public-route-name}-${count.index}"
  count            = var.vpc-count
  project = var.project_id
  network          = google_compute_network.csye-vpc[count.index].id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

# FIREWALLS

resource "google_compute_firewall" "healthcheck_firewall" {
  name = "ingress-healthcheck-firewall"
  count = var.vpc-count
  allow {
    protocol = "tcp"
    ports = [ "8000" ]
  }
  direction = "INGRESS"
  project = var.project_id
  network = google_compute_network.csye-vpc[count.index].id
  priority = 600
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags = ["webapp"]

}

resource "google_compute_firewall" "allow_proxy_firewall" {
  name = "ingress-allow-proxy"
  count = var.vpc-count
  allow {
    protocol = "tcp"
    ports = ["8000", "80", "443", "22"]
  }
  direction = "INGRESS"
  network = google_compute_network.csye-vpc[count.index].id
  project = var.project_id
  priority = 600
  source_ranges = [var.proxy-subnet-cidr]
  target_tags = ["webapp"]
}

# resource "google_compute_firewall" "webapp_ingress_firewall" {
#   name    = "webapp-ingress-firewall"
#   count = var.vpc-count
#   project = var.project_id
#   network = google_compute_network.csye-vpc[count.index].id
#   priority = var.allow-firewall-priority

#   allow {
#     protocol = var.traffic-type
#     ports    = var.allowed-ports-to-instance
#   }

#   source_ranges = [
#     "0.0.0.0/0"
#   ]

#   target_tags = [
#     "webapp"
#   ]
# }

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


# COMPUTE RESOURCES

resource "google_compute_region_instance_template" "webapp_template" {
  name_prefix = "webapp-instance-"
  project = var.project_id
  machine_type = var.compute-machine-type
  region = var.region

  disk {
    source_image = var.compute-image
    boot = true
    mode = "READ_WRITE"
    disk_type = var.compute-instance-disk-type
    disk_size_gb = var.compute-disk-size

    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm-key.id
    }
  }

  network_interface {
    # access_config {
    #   network_tier = "PREMIUM"
    # }

    stack_type = var.stack-type
    subnetwork = google_compute_subnetwork.webapp[0].self_link
  }

  service_account {
    email = google_service_account.instance_service_account.email
    scopes = [ "cloud-platform" ]
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

  tags = [ "webapp" ]

  depends_on = [ 
    google_compute_network.csye-vpc[0],
    google_sql_database_instance.database_instance, 
    google_sql_database.sql_database,
    google_sql_user.sql_user, 
    google_compute_address.private_ip_address,
    google_service_account.instance_service_account,
    google_pubsub_topic.verify_email_1,
    google_kms_crypto_key_iam_binding.vm_key_iam_binding
  ]
}

# Compute : Managed Instance group 
resource "google_compute_region_instance_group_manager" "webapp_instance_group" {
  name = var.instance-group-name
  project = var.project_id
  base_instance_name = var.base-instance-name
  region = var.region
  distribution_policy_zones = var.distribution-zones

  version {
    name = "primary"
    instance_template = google_compute_region_instance_template.webapp_template.self_link
  }

  auto_healing_policies {
    health_check = google_compute_region_health_check.healthcheck.id
    initial_delay_sec = 60
  }

  named_port {
    name = var.port-name
    port = 8000
  }

  # update_policy {
  #   type                           = "PROACTIVE"
  #   instance_redistribution_type   = "PROACTIVE"
  #   minimal_action                 = "REPLACE"
  #   most_disruptive_allowed_action = "REPLACE"
  #   max_surge_percent              = 0
  #   max_unavailable_fixed          = 2
  #   replacement_method             = "RECREATE"
  # }

  depends_on = [ google_compute_region_instance_template.webapp_template ]

}


# APPLICATION LOAD BALANCER COMPONENTS

#healthcheck
resource "google_compute_region_health_check" "healthcheck" {
  name = "compute-healthcheck"
  project = var.project_id
  region = var.region
  check_interval_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 2
  timeout_sec = 5
  http_health_check {
    port = 8000
    port_specification = "USE_FIXED_PORT"
    request_path = "/healthz"
    proxy_header = "NONE"

  }
}

# resource "google_compute_health_check" "healthcheck" {
#   name = "compute-healthcheck"
#   project = var.project_id
#   check_interval_sec = 5
#   healthy_threshold = 2
#   unhealthy_threshold = 2
#   timeout_sec = 5
#   http_health_check {
#     port = 8000
#     port_specification = "USE_FIXED_PORT"
#     request_path = "/healthz"
#     proxy_header = "NONE"

#   }
# }

#backend service
resource "google_compute_region_backend_service" "backend_service" {
  name                  = var.backend-name
  region                = var.region
  project = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.healthcheck.id]
  protocol              = "HTTP"
  port_name = var.port-name
  session_affinity      = "NONE"
  timeout_sec           = 30
  backend {
    group           = google_compute_region_instance_group_manager.webapp_instance_group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  depends_on = [ 
    google_compute_region_health_check.healthcheck,
    google_compute_region_instance_group_manager.webapp_instance_group
   ]

}

# resource "google_compute_backend_service" "backend_service" {
#   name                  = var.backend-name
#   project = var.project_id
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   health_checks         = [google_compute_health_check.healthcheck.id]
#   protocol              = "HTTP"
#   port_name = var.port-name
#   session_affinity      = "NONE"
#   timeout_sec           = 30
#   backend {
#     group           = google_compute_region_instance_group_manager.webapp_instance_group.instance_group
#     balancing_mode  = "UTILIZATION"
#     capacity_scaler = 1.0
#   }

#   depends_on = [ 
#     google_compute_health_check.healthcheck,
#     google_compute_region_instance_group_manager.webapp_instance_group
#    ]

# }


#URL map
resource "google_compute_region_url_map" "url_map" {
  name = var.url-map-name
  project = var.project_id
  region = var.region
  default_service = google_compute_region_backend_service.backend_service.id

  depends_on = [ 
    google_compute_region_backend_service.backend_service
   ]
}

# resource "google_compute_url_map" "url_map" {
#   name = var.url-map-name
#   project = var.project_id
#   default_service = google_compute_backend_service.backend_service.id

#   depends_on = [ 
#     google_compute_backend_service.backend_service
#    ]
# }

# SSL certificate
resource "google_compute_region_ssl_certificate" "ssl" {
  name_prefix = "ssl-certificate-"
  project = var.project_id
  private_key = file(var.private_key_path)
  certificate = file(var.certificate_file_path)
  region = var.region

  lifecycle {
    create_before_destroy = true
  }
}

# resource "google_compute_managed_ssl_certificate" "ssl_global" {
#   name     = "myservice-ssl-cert"
#   project = var.project_id

#   managed {
#     domains = [var.dns-name]
#   }
# }


#Target http proxy
resource "google_compute_region_target_https_proxy" "https_proxy" {
  name = var.target-proxy-name
  project = var.project_id
  region = var.region
  url_map = google_compute_region_url_map.url_map.id
  ssl_certificates = [ google_compute_region_ssl_certificate.ssl.id ]

  depends_on = [
    google_compute_region_url_map.url_map,
    google_compute_region_ssl_certificate.ssl
   ]
}

# resource "google_compute_target_https_proxy" "https_proxy" {
#   name = var.target-proxy-name
#   project = var.project_id
#   url_map = google_compute_url_map.url_map.id
#   ssl_certificates = [ google_compute_managed_ssl_certificate.ssl_global.id ]

#   depends_on = [
#     google_compute_url_map.url_map,
#     google_compute_managed_ssl_certificate.ssl_global
#    ]
# }


#External IP address
resource "google_compute_address" "default" {
  name         = "lb-address"
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  region       = var.region
  project = var.project_id
}

# resource "google_compute_global_address" "default" {
#   name         = "lb-address"
#   address_type = "EXTERNAL"
#   project = var.project_id
# }

resource "google_compute_forwarding_rule" "load_balancing_forwarding_rule" {
  name       = var.lb-forwarding-rule-name
  project = var.project_id
  region = var.region

  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.https_proxy.id
  ip_address            = google_compute_address.default.id
  network = google_compute_network.csye-vpc[0].id
  network_tier = "STANDARD"

  depends_on = [
    google_compute_subnetwork.proxy_only_subnet,
    google_compute_region_target_https_proxy.https_proxy,
    google_compute_network.csye-vpc[0],
    google_compute_address.default
  ]
}

resource "google_compute_region_autoscaler" "autoscale" {
  name = var.autoscaler-name
  project = var.project_id
  region = var.region
  target = google_compute_region_instance_group_manager.webapp_instance_group.id

  autoscaling_policy {
    max_replicas    = var.max_instances
    min_replicas    = var.min_instances
    cooldown_period = var.cooldown_period

    cpu_utilization {
      target = var.cpu_utilization
    }
  }

  depends_on = [ google_compute_region_instance_group_manager.webapp_instance_group ]
}

# DATABASE RESOURCES

resource "google_sql_database_instance" "database_instance" {
  name = "newdb"
  project = var.project_id
  deletion_protection = var.database-deletion-protection
  database_version = var.database-version
  region = var.region
  encryption_key_name = google_kms_crypto_key.sql-key.id
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
  depends_on = [ 
    google_kms_crypto_key_iam_binding.sql_key_iam_binding
   ]

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
  special = false
}


# SERVICE ACCOUNTS
resource "google_service_account" "instance_service_account" {
  account_id = var.service-account-id
  display_name = var.service-account-display-name
  project = var.project_id
}

resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  service  = "sqladmin.googleapis.com"
}

data "google_storage_project_service_account" "gcs_account" {
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

resource "google_kms_crypto_key_iam_binding" "vm_key_iam_binding" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.vm-key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${var.compute_service_agent}",
  ]

  depends_on = [ google_kms_crypto_key.vm-key ]
}

resource "google_kms_crypto_key_iam_binding" "sql_key_iam_binding" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.sql-key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}",
  ]

  depends_on = [ 
    google_project_service_identity.gcp_sa_cloud_sql,
    google_kms_crypto_key.sql-key
   ]
}

resource "google_kms_crypto_key_iam_binding" "storage_key_iam_binding" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.storage-key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}",
  ]

  depends_on = [ google_kms_crypto_key.storage-key]
}

# DNS
resource "google_dns_record_set" "compute_instance_ip_record" {
  name = var.dns-name
  type = "A"
  ttl = 30
  project = var.project_id

  managed_zone = var.dns-managed-zone-name
  # rrdatas = [ google_compute_instance.new_instance.network_interface[0].access_config[0].nat_ip ]
  rrdatas = [google_compute_address.default.address]
  depends_on = [ google_compute_address.default ]
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
  message_retention_duration = "604800s"
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
      DATABASE_HOST = google_compute_address.private_ip_address.address,
      MAILGUN_KEY = var.mailgun_key
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

resource "google_storage_bucket" "bucket" {
  name = var.bucket-name
  location = var.region
  force_destroy = true
  project = var.project_id

  encryption {
    default_kms_key_name = google_kms_crypto_key.storage-key.id
  }

  depends_on = [ google_kms_crypto_key_iam_binding.storage_key_iam_binding ]
}

resource "google_storage_bucket_object" "function-object" {
  name   = "function-source.zip"
  bucket = var.bucket-name
  source = data.archive_file.default.output_path # Add path to the zipped function source code

  depends_on = [ 
    google_storage_bucket.bucket
   ]
}

# Key ring

resource "google_kms_key_ring" "my_key_ring" {
  name     = var.key_ring_name
  project = var.project_id
  location = var.region
}

# Keys

resource "google_kms_crypto_key" "vm-key" {
  name = var.vm_key_name
  key_ring = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [ google_kms_key_ring.my_key_ring ]
}

resource "google_kms_crypto_key" "sql-key" {
  name = var.sql_key_name
  key_ring = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [ google_kms_key_ring.my_key_ring ]
}

resource "google_kms_crypto_key" "storage-key" {
  name = var.storage_key_name
  key_ring = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [ google_kms_key_ring.my_key_ring ]
}