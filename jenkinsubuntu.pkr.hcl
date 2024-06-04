packer {
  required_plugins {
    amazon = {
      version = ">=1.3.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "Jenkins-AMI"
  instance_type = "t2.small"
  region        = "us-east-1"
  source_ami    = "ami-04b70fa74e45c3917"
  ssh_username  = "ubuntu"
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 8
    volume_type = "gp2"
    encrypted   = true
    kms_key_id  = "alias/ami2_key-alias"
  }
}

build {
  name    = "jenkins-build"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "#!/bin/bash",
      "",
      "# Update package list",
      "sudo apt update -y",
      "",
      "# Install Java 11 JDK",
      "sudo apt install openjdk-11-jdk -y",
      "",
      "# Install Maven, wget, and unzip",
      "sudo apt install maven wget unzip -y",
      "",
      "# Add Jenkins repository key",
      "curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null",
      "",
      "# Add Jenkins repository",
      "echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null",
      "",
      "# Update package list again (to include Jenkins repository)",
      "sudo apt-get update -y",
      "",
      "# Install Jenkins",
      "sudo apt-get install jenkins -y",
      "",
      "# Enable UFW (Uncomplicated Firewall)",
      "sudo ufw --force enable",
      "",
      "# Allow incoming traffic on port 8080 (Jenkins web interface)",
      "sudo ufw allow 8080/tcp"
    ]
  }

  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
  }

  post-processor "shell-local" {
    inline = [
      "AMI_ID=$(jq -r '.builds[-1].artifact_id' manifest.json | cut -d ':' -f 2)",
      "aws ec2 copy-image \\",
      "  --source-image-id $AMI_ID \\",
      "  --source-region us-east-1 \\",
      "  --name \"Jenkins-AMI-Copy\" \\",
      "  --region us-west-2",
      "",
      "aws ec2 modify-image-attribute \\",
      "  --image-id $AMI_ID \\",
      "  --launch-permission \"Add=[{UserId=280435798514}]\" \\",
      "  --region us-east-1"
    ]
  }
}
