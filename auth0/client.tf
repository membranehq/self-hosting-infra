resource "auth0_client" "api" {
  name                = "DEV Auth0 Client"
  description         = "DEV Auth0 Client created by Vadym for dev AWS account"
  app_type            = "spa"
  callbacks           = ["https://console.int-membrane.com", "https://console.azure.int-membrane.com"]
  allowed_origins     = ["https://console.int-membrane.com", "https://console.azure.int-membrane.com"]
  allowed_logout_urls = ["https://console.int-membrane.com", "https://console.azure.int-membrane.com"]
  oidc_conformant     = true
  cross_origin_auth   = true
  cross_origin_loc    = "https://console.int-membrane.com, https://console.azure.int-membrane.com"
  web_origins         = ["https://console.int-membrane.com", "https://console.azure.int-membrane.com"]
  initiate_login_uri  = "https://console.int-membrane.com"


  jwt_configuration {
    alg = "RS256"
  }
}