/*==== Gatthering of availability zones in the present region from datasource ======*/

data "aws_availability_zones" "available_azs" {
  state = "available"
}
data "aws_route53_zone" "selected" {
  name         = "pratheeshsatheeshkumar.tech."
  private_zone = false
}
