provider "aws" {
    profile="deepak"
    region="ap-south-1"
}
/*
resource "aws_key_pair" "key" {
  key_name   = "mykey1122"
  public_key = file("mykey1122.pem")
}
*/
//creating security group

resource  "aws_security_group"  "web-SG" {
name        = "Web-envi-SG"
description = "Web enviornment security group"
 vpc_id      = "vpc-167a637e"
 
ingress {

description = "SSH rule"
from_port   = 22
to_port     = 22
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
     }

     ingress {
description = "HTTP rule"
from_port   = 80
to_port     = 80
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "web-sg"
  }
}

resource "aws_instance" "myinstance" {
  ami             = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        = "mykey1122"
  security_groups = ["web-sg"]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("C:/Users/deepak/Downloads/mykey1122.pem")
    host        = aws_instance.myinstance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "OS1"
  }
}

output "InstanceIP" {
  value = aws_instance.myinstance.public_ip
}

resource "aws_efs_file_system" "efs1" {
  creation_token = "efs1"

  tags = {
    Name = "new efs"
  }
}

resource "aws_efs_mount_target" "efs_attachment" {
  depends_on = [aws_efs_file_system.efs1,]
  file_system_id    = aws_efs_file_system.efs1.id
  subnet_id  = aws_instance.myinstance.subnet_id
  security_groups = [aws_security_group.web-sg.id]
}
resource "null_resource" "remote" {
  depends_on = [
    aws_efs_mount_target.efs_attachment,
  ]


  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("C:/Users/deepak/Downloads/mykey1122.pem")
    host        = aws_instance.myinstance.public_ip
  }
  provisioner "remote-exec" {
    inline = ["sudo echo ${aws_efs_file_system.efs1.dns_name}: /var/www/html efs defaults,_netdev 0 0 >>sudo/etc/fstab",
              "sudo mount echo ${aws_efs_file_system.efs1.dns_name}: /var/www/html",
              "sudo rm -rf /var/www/html/*",
              "sudo git clone https://github.com/DEEPAKKAUSHIK11/task2.git /var/www/html",
              "sudo systemctl restart httpd",
              "sudo sed -i 's/cfid/${aws_cloudfront_distribution.cf_distribution.domain_name}/g' /var/www/html/index.html",
    ]
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "deepak1234-bucket"
  acl    = "public-read"

  tags = {
    Name        = "kaushik"
    Environment = "prod"
  }
}
/*
output "s3" {
  value = aws_s3_bucket.bucket.bucket_regional_domain_name
}
*/

resource "aws_s3_bucket_object" "file_upload" {
  depends_on = [
    aws_s3_bucket.bucket,
  ]
  bucket = "kaushik-bucket"
  key    = "cartoonimage.jpg"
  source = ""C:/Users/deepak/Desktop/cartoonimage.jpg"

}
resource "aws_cloudfront_distribution" "cf_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "myweb"

    custom_origin_config {
      http_port              = 80
      https_port             = 80
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  enabled = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "myweb"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
/*
output "CLoudFrontURL" {
  value = aws_cloudfront_distribution.cf_distribution.domain_name
}
*/
resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
	 {
         "Sid":"AllowPublicRead",
         "Effect":"Allow",
         "Principal": {
            "AWS":"*"
         },
         "Action":"s3:GetObject",
         "Resource":"arn:aws:s3:::deepak1234-bucket/*"
      }
    ]
}
POLICY
}
