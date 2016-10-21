# User-data script
data "template_file" "vault" {
  template = "${file("${path.module}/templates/vault.sh.tpl")}"
  vars {
    hostname        = "${var.namespace}-vault"
    vault_address   = "${var.vault_address}"
    vault_version   = "${var.vault_version}"
    ssl_certificate = "${tls_self_signed_cert.default.cert_pem}"
    ssl_private_key = "${tls_private_key.default.private_key_pem}"
  }
}

# Vault server
resource "aws_instance" "vault" {
  ami           = "${data.aws_ami.ubuntu-1404.id}"
  instance_type = "t2.micro"

  key_name = "${aws_key_pair.default.key_name}"

  subnet_id              = "${aws_subnet.default.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  tags {
    Name = "${var.namespace}-vault"
  }

  user_data = "${data.template_file.vault.rendered}"
}

output "vault" {
  value = "${aws_instance.vault.public_ip}"
}
