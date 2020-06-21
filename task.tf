provider "aws" {
  region  = "ap-south-1"
  profile = "yugal"
}

resource "tls_private_key" "mykey121" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "mykey1" {
  content         = "${tls_private_key.mykey121.private_key_pem}"
  filename        = "key123.pem"
  file_permission = 0400
}

resource "aws_key_pair" "key98" {
  key_name   = "key123"
  public_key = "${tls_private_key.mykey121.public_key_openssh}"
}

resource "aws_security_group"  "myfirewall" {
  name        = "myfirewall"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-3d445a55"
 

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = {
    Name = "myfirewall"
  }
}

resource "aws_instance" "web" {

depends_on = [
  aws_security_group.myfirewall,
 ]

  ami             = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        = "key123"
  security_groups = [ "myfirewall" ]

  connection {
    type          = "ssh"
    user          = "ec2-user"
    private_key   = "${tls_private_key.mykey121.private_key_pem}"
    host          = "${aws_instance.web.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "FirstOs"
  }

}

resource "aws_ebs_volume" "ebsvol1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "my_ebs_vol1"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebsvol1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal2"  {
  provisioner "local-exec" {
    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  }
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = "${tls_private_key.mykey121.private_key_pem}"
    host        = "${aws_instance.web.public_ip}"
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/yugal121/HybridCloud.git /var/www/html/", 
      "sudo su << EOF",
         "echo \"${aws_cloudfront_distribution.s3_distribution.domain_name}\" >> /var/www/html/path.txt",
         "EOF",
      "sudo systemctl restart httpd"
    ]
  }
}
	

resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
  ]

    provisioner "local-exec" {
      command = "chrome  ${aws_instance.web.public_ip}"
  	}
}


resource "aws_s3_bucket" "bucket1" {
  bucket = "my-test-bucket"
  

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "null_resource" "images_repo"  {
  provisioner "local-exec" {
    command = "git clone https://github.com/yugal121/HybridCloud.git  image1"
  }
  provisioner "local-exec" {
  when      = destroy
    command = "rm -rf image1"
  }
}

  
resource "aws_s3_bucket_object" "obj1" {
  bucket = "${aws_s3_bucket.bucket1.bucket}"
  key    = "VimalSir.jpg"
  source = "C:/Users/dell/Desktop"
  
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.bucket1.bucket_regional_domain_name}"
    origin_id   = aws_s3_bucket.bucket1.id
    
    custom_origin_config {
      http_port              = 80
      https_port             = 1234
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2", "TLSv1.3"]
    }
  } 
  
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.bucket1.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
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

resource "aws_ebs_snapshot" "ebs_snapshot" {
  volume_id = "${aws_ebs_volume.ebsvol1.id}"

  tags = {
    Name = "ebs-snap-1"
  }
}

