resource "aws_s3_bucket" "example" {
  bucket = var.bucket-name

  tags = {
    PullImage = "From ec2"
  }
}
