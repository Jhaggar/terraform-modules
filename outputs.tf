# Output to be displayed on console
#------------------------------------------------------------------------------------------------------
output "arn" {
  value = aws_db_instance.postgresql.arn
}

output "endpoint" {
  value = aws_db_instance.postgresql.endpoint
}

output "id" {
  value = aws_db_instance.postgresql.id
}

output "secretpassword" {
  sensitive = true
  value = aws_secretsmanager_secret_version.secretValue.secret_string
}