# Fetch latest amazon_linux image
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Fetch default VPC & Subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# IAM role for SSM
# https://youtu.be/SwSEmvWMuMU?si=W9mdoXpyXIAkMaHz
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM policy to read Docker creds and pull image to s3
resource "aws_iam_policy" "ssm_s3_policy" {
  name = "ssm-docker-parameters"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/docker/*"
      },
      {
        Effect = "Allow"
        Action   = ["s3:PutObject","s3:PutObjectAcl"]
        Resource = "arn:aws:s3:::migulopez-bucket-29092025/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Resourge group to allow connection only from my IP
resource "aws_security_group" "sg" {
  name        = "http-sg"
  description = "Allow connection to docker port only with my IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = [var.cidr_blocks]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# https://github.com/terraform-aws-modules/terraform-aws-ec2-instance/blob/master/main.tf
resource "aws_instance" "ec2-docker" {

  count                       = length(var.instances)
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  user_data                   = var.instances[count.index].user_data
  vpc_security_group_ids      = [aws_security_group.sg.id]

  tags = {
    Name = var.instances[count.index].name
  }

}
