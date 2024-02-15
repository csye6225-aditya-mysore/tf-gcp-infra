variable "credentials_file" {
  type    = string
  default = "~/Documents/GCloud/keys/csye6225-aditya-mysore-9280c98e589c.json"
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