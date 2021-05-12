path "database/creds/app-user" {
  capabilities = ["read"]
}

path "database/roles" {
  capabilities = ["list"]
}

path "database/roles/app-user" {
  capabilities = ["read"]
}
