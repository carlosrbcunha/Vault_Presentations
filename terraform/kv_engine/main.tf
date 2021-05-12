
resource "vault_mount" "kv1" {
  path        = "kv1"
  type        = "kv"
  description = "This is an example mount for kv version 1"
}
resource "vault_mount" "kv2" {
  path        = "kv2"
  type        = "kv-v2"
  description = "This is an example mount for kv version 2"
}

# LOAD DUMMY DATA
resource "vault_generic_secret" "kv1-DUMMY1" {
  path = "kv1/app1"

  data_json = <<EOT
{
  "username":   "admin",
  "password": "ja75hg3ks973"
}
EOT
}

resource "vault_generic_secret" "kv2-DUMMY1" {
  path = "kv2/app1"

  data_json = <<EOT
{
  "username":   "admin",
  "password": "ja75hg3ks93"
}
EOT
}
