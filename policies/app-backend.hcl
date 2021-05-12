path "database/creds/app-backend" {
  capabilities = ["read"]
}

path "database/roles" {
  capabilities = ["list"]
}

path "database/roles/app-backend" {
  capabilities = ["read"]
}
