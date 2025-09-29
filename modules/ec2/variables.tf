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
  default = "X.X.X.X/X"
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
