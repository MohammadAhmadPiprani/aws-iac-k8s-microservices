variable "region" {
  default     = "eu-west-2"
  description = "London"
}

variable "my_ip" {
  type        = string
  description = "153.117.55.147/24"
}


variable "key_pair" {
  description = "london_kp"
  type        = string
}

variable "instance_type" {
  default = "m7i-flex.large"
}


