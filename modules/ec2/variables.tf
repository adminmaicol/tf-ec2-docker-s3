variable "name" {
  type    = string
  default = "ec2-docker"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "cidr_blocks" {
  type    = string
  default = "187.243.195.127/32"
}

variable "port" {
  type    = number
  default = 1809
}

variable "instances" {
  type = list(object({
    name      = string
    user_data = string
  }))
}
