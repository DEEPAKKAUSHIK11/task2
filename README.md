# task2
Hybrid Multi Cloud Task-2

TASK 2 of Hybrid Multi Cloud Computing .

In this task we use EFS ( Elastic File Storage ) instead of EBS volumes .
OBJECTIVE:-

1. Create Security group which allow the port 80.

2. Launch EC2 instance.

3. In this Ec2 instance use the existing key or provided key and security group which we have created in step 1.

4. Launch one Volume using the EFS service and attach it in your vpc, then mount that volume into /var/www/html

5. Developer have uploded the code into github repo also the repo has some images.

6. Copy the github repo code into /var/www/html

7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.

8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to update in code in /var/www/html

1)Create key-pair and security group (allowing port no 80)for EC2 instance.

provider "aws" {
	    profile="deepak"
	    region="ap-south-1"
	}
	
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

No alt text provided for this image

2)Creating and launching EC2 instance with key-pair and security group that created in step 1 and connect to instance by using remote login in terraform.

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

No alt text provided for this image

3)Create Elastic File System (EFS) for storage . Using Elastic File System we can edit our content stored in it which is not provided by S3 and EBS volumes . After creating Elastic File System for our instance we have to mount it in our VPC .These EFS can be accessible from anywhere in the VPC not like EBS which requires to be in same data center where instance is running .

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

No alt text provided for this image

4) We have to launch our instance for web application .Developer have uploaded the code for web application in github ,we have to clone the code from git hub repo into folder called /var/www/html . Before these all httpd services for apache web server should be installed in the instance .

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

5)Creating S3 bucket and cloudfront which access the object of S3 bucket.

resource "aws_s3_bucket" "bucket" {
	  bucket = "deepak1234-bucket"
	  acl    = "public-read"
	

	  tags = {
	    Name        = "kaushik"
	    Environment = "prod"
	  }

	
}

No alt text provided for this image

6)creating bucket object and deploy images from git repo.

resource "aws_s3_bucket_object" "file_upload" {
	  depends_on = [
	    aws_s3_bucket.bucket,
	  ]
	  bucket = "kaushik-bucket"
	  key    = "cartoonimage.jpg"
	  source = ""C:/Users/deepak/Desktop/cartoonimage.jpg"
	

	}


No alt text provided for this image

7) To access the bucket object as image we have to create one cloud front using S3 which will work as Content Delivery Netowk . Using , the URL provided by cloud front we can update our code .

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

No alt text provided for this image

8) Finally ,the whole infrastructure is ready . We can now access website application using , public IP of web server instance . You can also automate these part using echo command in local provision-er .
Final out put Image
No alt text provided for this image


Finally all the completion process of the task is done through writing code in terraform.

Thank you 

