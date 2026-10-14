variable "env" {
  type = string
}

variable "list_of_services" {
  type    = set(string)
  default = [
  "adservice",
  "cartservice",
  "checkoutservice",
  "currencyservice",
  "emailservice",
  "frontend",
  "loadgenerator",
  "paymentservice",
  "productcatalogservice",
  "recommendationservice",
  "shippingservice",
  "shoppingassistantservice"
]  
}