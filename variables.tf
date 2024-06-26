variable "credentials_file" {
  type    = string
  default = "~/Documents/GCloud/keys/dev-aditya-mysore-8ec41076eab4.json"
}

variable "project_id" {
  type    = string
  default = "dev-aditya-mysore"
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "zone" {
  type    = string
  default = "us-east1-b"
}

variable "webapp-subnet-cidr-range" {
  type    = string
  default = "10.1.0.0/24"
}

variable "db-subnet-cidr-range" {
  type    = string
  default = "10.1.1.0/24"
}

variable "vpc-name" {
  type    = string
  default = "csye-vpc"
}

variable "webapp-subnet-name" {
  type    = string
  default = "webapp-subnet"
}

variable "db-subnet-name" {
  type    = string
  default = "db-subnet"
}

variable "vpc-count" {
  type    = number
  default = 1
}

variable "public-route-name" {
  type    = string
  default = "public-route-for-webapp"
}

variable "cidr-range" {
  type    = string
  default = "10.1.0.0/20"
}

variable "number-of-subnets" {
  type    = number
  default = 2
}

variable "routing-mode" {
  type    = string
  default = "REGIONAL"
}

variable "auto-create-subnets-boolean" {
  type    = bool
  default = false
}

variable "delete-default-routes-on-create" {
  type    = bool
  default = false
}

variable "compute-image" {
  type    = string
  default = "projects/dev-aditya-mysore/global/images/practice-image-centos-8"
}

variable "compute-instance-name" {
  type    = string
  default = "my-instance"
}

variable "stack-type" {
  type    = string
  default = "IPV4_ONLY"
}

variable "compute-disk-size" {
  type    = number
  default = 100
}

variable "compute-machine-type" {
  type    = string
  default = "e2-micro"
}

variable "app-port" {
  type    = string
  default = "8000"
}

variable "compute-instance-disk-type" {
  type    = string
  default = "pd-balanced"
}

variable "compute-instance-automatic-restart" {
  type    = bool
  default = true
}

variable "on-host-maintenance" {
  type    = string
  default = "MIGRATE"
}

variable "preemptible" {
  type    = bool
  default = false
}

variable "provisioning-model" {
  type    = string
  default = "STANDARD"
}

variable "compute-disk-autodelete" {
  type    = bool
  default = true
}

variable "allow-firewall-priority" {
  type    = number
  default = 999
}

variable "deny-firewall-priority" {
  type    = number
  default = 1000
}

variable "traffic-type" {
  type    = string
  default = "tcp"
}

variable "private-ip-address" {
  type = string
  default = "198.167.0.5"
}

variable "allowed-ports-to-instance" {
  type = list(string)
  default = [ "8000", "5432" ]
}

variable "database-version" {
  type = string
  default = "POSTGRES_15"
}

variable "database-disk-size" {
  type = number
  default = 100
}

variable "database-tier" {
  type = string
  default = "db-custom-2-7680"
}

variable "database-deletion-protection" {
  type = bool
  default = false
}

variable "service-account-id" {
  type = string
  default = "logging"
}

variable "service-account-display-name" {
  type = string
  default = "logging_service_account"
}

variable "dns-name" {
  type = string
  default = "adityawebapp.com."
}

variable "dns-managed-zone-name" {
  type = string
  default = "aditya-csye6225-dns"
}

variable "vpc-connector-ip-cidr" {
  type = string
  default = "198.166.0.0/28"
}

variable "pubsub-topic-name" {
  type = string
  default = "verify_email_1"
}

variable "bucket-name" {
  type = string
  default = "aditya-csye6225"
}

variable "function-object-zip-name" {
  type = string
  default = "function-source.zip"
}

variable "function-entry-point" {
  type = string
  default = "helloPubSub"
}

variable "distribution-zones" {
  type = list(string)
  default = [ "us-east1-b", "us-east2-c" ]
}

variable "proxy-subnet-cidr" {
  type = string
  default = "192.168.8.0/24"
}

variable "instance-group-name" {
  type = string
  default = "webapp-managed-instance-group"
}

variable "base-instance-name" {
  type = string
  default = "webapp-instance"
}

variable "port-name" {
  type = string
  default = "http"
}

variable "backend-name" {
  type = string
  default = "backend"
}

variable "url-map-name" {
  type = string
  default = "default-url-map"
}

variable "target-proxy-name" {
  type = string
  default = "http-proxy"
}

variable "lb-forwarding-rule-name" {
  type = string
  default = "ld-forwarding-rule"
}

variable "autoscaler-name" {
  type = string
  default = "default-autoscaler"
}

variable "cpu_utilization" {
  type = number
  default = 0.05
}

variable "max_instances" {
  type = number
  default = 10
}

variable "min_instances" {
  type = number
  default = 1
}

variable "certificate_file_path" {
  type = string
  default = "./certificate/adityawebapp_com.crt"
}

variable "private_key_path" {
  type = string
  default = "./certificate/private.key"
}

variable "cooldown_period" {
  type = number
  default = 60
}

variable "vm_key_name" {
  type = string
  default = "csye6225-vm-key"
}

variable "sql_key_name" {
  type = string
  default = "csye6225-sql-key"
}

variable "storage_key_name" {
  type = string
  default = "csye6225-storage-key"
}

variable "key_ring_name" {
  type = string
  default = "csye6225-1"
}

variable "compute_service_agent" {
  type = string
  default = "service-205010625050@compute-system.iam.gserviceaccount.com"
}

variable "mailgun_key" {
  type = string
  default = "value"
}