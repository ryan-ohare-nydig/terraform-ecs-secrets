# ECS Task Execution IAM Role
// this policy allows the role who owns it to assume the identity
// of ecs-tasks.amazonaws.com service.
data "aws_iam_policy_document" "ecs_task_execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

// default task execution policy used for ECS tasks.
// By default it is attached to ecsTaskExecutionRole which is the default role used in
// ECS tasks
data "aws_iam_policy" "ecs_task_execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// make an IAM role for the task to to run under. Base will have have only the ecs
// task execution policy (same as the default role) and this will be set as an
// assume role policy
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution"

  // allow this task to assume the role of ecs services
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json
  path               = "/"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution.arn
}

# Random password
resource "random_password" "database_password" {
  length  = 16
  special = false
}