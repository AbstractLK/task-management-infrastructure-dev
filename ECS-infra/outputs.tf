output "alb_dns_name" {
  description = "The public URL of your application"
  value       = aws_lb.microservices_alb.dns_name
}