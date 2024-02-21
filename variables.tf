variable "credentials_file" {
  type    = string
  default = "~/Documents/GCloud/keys/dev-aditya-mysore-8ec41076eab4.json"
}

variable "project_id" {
  type    = string
  default = "csye6225-aditya-mysore"
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
  type = string
  default = "public-route-for-webapp"
}

variable "cidr-range" {
  type = string
  default = "10.1.0.0/20"
}

variable "number-of-subnets" {
  type = number
  default = 2
}

variable "routing-mode" {
  type = string
  default = "REGIONAL"
}

variable "auto-create-subnets-boolean" {
  type = bool
  default = false
}

variable "delete-default-routes-on-create" {
  type = bool
  default = false
}

variable "compute-image" {
  type = string
  default = "projects/dev-aditya-mysore/global/images/practice-image-centos-8"
}

variable "compute-instance-name" {
  type = string
  default = "my-instance"
}

variable "stack-type" {
  type = string
  default = "IPV4_ONLY"
}

variable "compute-disk-size" {
  type = number
  default = 100
}

variable "compute-machine-type" {
  type = string
  default = "e2-micro"
}

variable "app-port" {
  type = string
  default = "8000"
}

variable "compute-instance-disk-type" {
  type = string
  default = "pd-balanced"
}

variable "compute-instance-automatic-restart" {
  type = bool
  default = true
}

variable "on-host-maintenance" {
  type = string
  default = "MIGRATE"
}

variable "preemptible" {
  type = bool
  default = false
}

variable "provisioning-model" {
  type = string
  default = "STANDARD"
}

variable "compute-disk-autodelete" {
  type = bool
  default = true
}