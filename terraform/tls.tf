resource "tls_private_key" "default" {
  algorithm = "ECDSA"
}

resource "tls_self_signed_cert" "default" {
  key_algorithm   = "${tls_private_key.default.algorithm}"
  private_key_pem = "${tls_private_key.default.private_key_pem}"

  validity_period_hours = 336 # 14 days

  is_ca_certificate = true

  dns_names = [
    "${var.vault_address}",
  ]

  subject {
    common_name  = "${var.vault_address}"
    organization = "ACME, Inc."
  }

  allowed_uses = [
    "digital_signature",
    "content_commitment",
    "key_encipherment",
    "data_encipherment",
    "key_agreement",
    "cert_signing",
    "encipher_only",
    "decipher_only",
    "any_extended",
    "server_auth",
    "client_auth",
    "code_signing",
    "email_protection",
    "ipsec_end_system",
    "ipsec_tunnel",
    "ipsec_user",
    "timestamping",
    "ocsp_signing",
    "microsoft_server_gated_crypto",
    "netscape_server_gated_crypto",
  ]
}
