terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token = var.token  
  cloud_id = var.cloud_id
  folder_id = var.folder_id
  zone = "ru-central1-a"
}

resource "yandex_vpc_address" "external-address" {
  name = "external-address"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_compute_instance" "jenkins" {
  name        = "jenkins"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8hqa9gq1d59afqonsf"
    }
  }

  #network_interface {
  #  subnet_id = yandex_vpc_subnet.subnet1.id
  #}

  network_interface {
    subnet_id      = yandex_vpc_subnet.subnet1.id
    nat            = true
    nat_ip_address = yandex_vpc_address.external-address.external_ipv4_address[0].address
  }

  metadata = {
    ssh-keys = "centos:${file(var.public_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install wget -y",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key",
      "sudo yum upgrade -y",
      "sudo yum install java-11-openjdk -y",
      "sudo yum install jenkins -y",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable jenkins",
      "sudo systemctl start jenkins",
    ]
	connection {
      type = "ssh"
      user = var.user
      private_key = file(var.private_key_path)
      host = self.network_interface[0].nat_ip_address
    }
  }
}

resource "yandex_vpc_network" "network1" {}

resource "yandex_vpc_subnet" "subnet1" {
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network1.id
}

output "public_ip_address" {
  value = yandex_compute_instance.jenkins.network_interface[0].nat_ip_address
}
