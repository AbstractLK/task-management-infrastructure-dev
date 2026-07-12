# ==========================================
# 1. NETWORKING (VPC, Subnets, IGW, Routing)
# ==========================================

resource "aws_vpc" "ecs_vpc" {
  cidr_block           = "10.0.0.0/16"
  tags = { Name = "ecs-microservices-vpc" }
}

# ALB requires at least 2 subnets in different AZs
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.ecs_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
  tags = { Name = "ecs-public-subnet-1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.ecs_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = true
  tags = { Name = "ecs-public-subnet-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecs_vpc.id
  tags = { Name = "ecs-microservices-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ecs_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# 2. SECURITY GROUPS
# ==========================================

# Security Group for the Load Balancer (Allows web traffic from the internet)
resource "aws_security_group" "alb_sg" {
  name        = "microservices-alb-sg"
  vpc_id      = aws_vpc.ecs_vpc.id
  description = "Allow inbound HTTP traffic to ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for the ECS Tasks (Allows traffic ONLY from the ALB)
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "microservices-ecs-tasks-sg"
  vpc_id      = aws_vpc.ecs_vpc.id
  description = "Allow inbound traffic from ALB only"

  ingress {
    from_port       = 80 # Assuming your frontend container maps to port 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 3. IAM ROLES & PARAMETER STORE
# ==========================================

resource "aws_ssm_parameter" "mongo_uri" {
  name  = "/microservices/MONGODB_URI"
  type  = "SecureString"
  value = var.mongo_uri
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/microservices/JWT_SECRET"
  type  = "SecureString"
  value = var.jwt_secret
}

# Task Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsTaskExecutionRole-TF"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Standard execution policy (Allows pulling images and writing logs)
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy to read the SSM Parameter
resource "aws_iam_role_policy" "ecs_ssm_policy" {
  name = "ECS-SSM-ReadSecrets"
  role = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "ssm:GetParameter"]
      Resource = ["arn:aws:ssm:*:*:parameter/microservices/*"]
    }]
  })
}

# ==========================================
# 4. APPLICATION LOAD BALANCER (ALB)
# ==========================================

resource "aws_lb" "microservices_alb" {
  name               = "microservices-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ecs_vpc.id
  target_type = "ip"

  health_check {
    path                = "/" # Update this if your app has a specific health check route (e.g., /health)
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.microservices_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# ==========================================
# 5. ECS CLUSTER, CLOUDWATCH LOGS & TASK DEFINITION
# ==========================================

resource "aws_ecs_cluster" "main_cluster" {
  name = "microservices-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/microservices-stack"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "microservices-stack"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024" # 1 vCPU
  memory                   = "2048" # 2 GB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "abstraxlk/task-management-frontend:3.2"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [{
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    },
    {
      name      = "auth-service"
      image     = "abstraxlk/task-management-auth-service:5.1"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        { name = "PORT", value = "4001" }
      ]
      secrets = [
        { name = "MONGODB_URI", valueFrom = aws_ssm_parameter.mongo_uri.arn },
        {name = "JWT_SECRET", valueFrom = aws_ssm_parameter.jwt_secret.arn}
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "auth"
        }
      }
    },
    {
      name      = "task-service"
      image     = "abstraxlk/task-management-task-service:5.1"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        { name = "PORT", value = "4002" }
      ]
      secrets = [
        { name = "MONGODB_URI", valueFrom = aws_ssm_parameter.mongo_uri.arn },
        {name = "JWT_SECRET", valueFrom = aws_ssm_parameter.jwt_secret.arn}
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "task"
        }
      }
    }
  ])
}

# ==========================================
# 6. ECS SERVICE
# ==========================================

resource "aws_ecs_service" "app_service" {
  name            = "microservices-app-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true # Required for Fargate tasks in public subnets to pull images from Docker Hub
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend"
    container_port   = 80
  }

  # Ensure the ALB is fully spun up before the service tries to register targets
  depends_on = [aws_lb_listener.http_listener] 
}