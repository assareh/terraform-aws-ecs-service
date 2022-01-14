### Network

// data "aws_availability_zones" "available" {}

// resource "aws_vpc" "main" {
//   cidr_block = "10.10.0.0/16"
// }

// resource "aws_subnet" "main" {
//   count             = var.az_count
//   cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
//   availability_zone = data.aws_availability_zones.available.names[count.index]
//   vpc_id            = aws_vpc.main.id
// }

// resource "aws_internet_gateway" "gw" {
//   vpc_id = aws_vpc.main.id
// }

// resource "aws_route_table" "r" {
//   vpc_id = aws_vpc.main.id

//   route {
//     cidr_block = "0.0.0.0/0"
//     gateway_id = aws_internet_gateway.gw.id
//   }
// }

// resource "aws_route_table_association" "a" {
//   count          = var.az_count
//   subnet_id      = element(aws_subnet.main.*.id, count.index)
//   route_table_id = aws_route_table.r.id
// }

data "aws_subnet" "selected" {
  id = var.subnet_id
}

### Security

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = var.vpc_id
  name   = "${var.name}-${var.environment}-ecs-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = var.vpc_id
  name        = "${var.name}-${var.environment}-ecs-inst-sg"

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    security_groups = [
      aws_security_group.lb_sg.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## ECS

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-${var.environment}-ecs-cluster"
}

resource "aws_ecs_service" "main" {
  name            = "${var.name}-${var.environment}-ecs-lbsg"
  cluster         = aws_ecs_cluster.main.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = "1"

  load_balancer {
    target_group_arn = aws_alb_target_group.test.id
    container_name   = var.name
    container_port   = "80"
  }

  network_configuration {
    security_groups  = [aws_security_group.instance_sg.id]
    subnets          = [data.aws_subnet.selected.*.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_alb_listener.front_end,
  ]
}

data "template_file" "task_definition" {
  template = file("${path.module}/task-definition.json")

  vars = {
    image_url        = var.docker_image
    container_name   = var.name
    log_group_name   = aws_cloudwatch_log_group.app.name
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name}-${var.environment}"
  container_definitions    = data.template_file.task_definition.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.task_init.arn
  cpu                      = 1024
  memory                   = 2048
}

## IAM

resource "aws_iam_role" "task_init" {
  name               = "${var.name}-${var.environment}-task-init-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_definition.json
}

data "aws_iam_policy_document" "assume_role_policy_definition" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy_attachment" "task_init_policy" {
  role       = aws_iam_role.task_init.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "task_init_policy" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "task_init_policy" {
  role   = aws_iam_role.task_init.name
  name   = "AllowlogsCreateLogGroup"
  policy = data.aws_iam_policy_document.task_init_policy.json
}

## ALB

resource "aws_alb" "main" {
  name            = "${var.name}-${var.environment}"
  subnets         = data.aws_subnet.selected.*.id
  security_groups = [aws_security_group.lb_sg.id]
}

resource "aws_alb_target_group" "test" {
  name        = "${var.name}-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.test.id
    type             = "forward"
  }
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.name}-${var.environment}/ecs"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.name}-${var.environment}/app"
}
