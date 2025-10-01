module "s3_bucket" {
  source = "./modules/s3"
}

module "ec2_instance" {
  source = "./modules/ec2"
  
  depends_on = [ module.s3_bucket ]

  # user_data = local.user_data_createimage
  instances = [
    {
      name      = "ec2-docker"
      user_data = <<-EOT
    #!/bin/bash
    # Exit inmmediately if a command fails, also Print each command before running it
    set -ex

    # Update system and install Docker
    yum update -y
    amazon-linux-extras install -y docker
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
    
    # Create nginx directory
    mkdir -p /home/ec2-user/nginx-app
    cat <<'EOF' > /home/ec2-user/nginx-app/index.html
    <!DOCTYPE html>
    <html>
    <head>
      <title>This is DevOps Terraform and Docker HandsOn</title>
    </head>
    <body>
      <h1>Imprimir</h1>
    </body>
    </html>
    EOF

    # Create Dockerfile
    cat <<'EOF' > /home/ec2-user/nginx-app/Dockerfile
    FROM nginx:latest
    COPY index.html /usr/share/nginx/html/index.html
    EXPOSE 1809
    EOF

    # Build and run Docker container
    cd /home/ec2-user/nginx-app
    docker build -t my-nginx-image .
    docker run -d -p 1809:80 my-nginx-image
  EOT
    },
    {
      name      = "ec2-s3"
      user_data = <<-EOT
  #!/bin/bash
  set -ex

  # Get region from EC2 instance metadata
  AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

  amazon-linux-extras enable docker
  yum install -y docker
  systemctl start docker
  systemctl enable docker

  DOCKER_USER=$(aws ssm get-parameter --region $AWS_REGION --name "/docker/username" --with-decryption --query "Parameter.Value" --output text)
  DOCKER_PASS=$(aws ssm get-parameter --region $AWS_REGION --name "/docker/password" --with-decryption --query "Parameter.Value" --output text)
  docker login -u $DOCKER_USER --password-stdin

  docker pull dockermigulopez/ec2-tf-docker-s3-lab:latest
  docker save dockermigulopez/ec2-tf-docker-s3-lab:latest -o /home/ec2-user/ec2-tf-docker-s3-lab.tar

  aws s3 cp /home/ec2-user/ec2-tf-docker-s3-lab.tar s3://migulopez-bucket-29092025/ --region us-west-2
  EOT
    }
  ]
}
