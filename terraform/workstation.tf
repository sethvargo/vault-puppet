# User-data script
data "template_file" "workstation" {
  template = "${file("${path.module}/templates/workstation.sh.tpl")}"
  vars {
    hostname          = "${var.namespace}-workstation"
    vault_ip          = "${aws_instance.vault.private_ip}"
    vault_address     = "${var.vault_address}"
    vault_version     = "${var.vault_version}"
    postgres_ip       = "${aws_instance.postgres.private_ip}"
    postgres_username = "${random_id.vault_username.hex}"
    postgres_password = "${random_id.vault_password.hex}"
    ssl_certificate   = "${tls_self_signed_cert.default.cert_pem}"
  }
}

# Workstation server
resource "aws_instance" "workstation" {
  ami           = "${data.aws_ami.ubuntu-1404.id}"
  instance_type = "t2.micro"

  key_name = "${aws_key_pair.default.key_name}"

  subnet_id              = "${aws_subnet.default.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  tags {
    Name = "${var.namespace}-workstation"
  }

  user_data = "${data.template_file.workstation.rendered}"
}

output "workstation" {
  value = "${aws_instance.workstation.public_ip}"
}
