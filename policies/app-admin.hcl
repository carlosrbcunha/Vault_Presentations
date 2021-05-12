path "database/creds/app-admin" {
  capabilities = ["read"]
}

path "database/roles" {
  capabilities = ["list"]
}

path "database/roles/app-admin" {
  capabilities = ["read"]
}
