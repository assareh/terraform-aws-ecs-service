output "alb_hostname" {
  value = aws_alb.main.dns_name
}

output "task_def" {
  value = aws_ecs_task_definition.main.arn
}
