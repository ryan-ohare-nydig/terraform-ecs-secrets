// create an SSM secret which will be used in the task file
resource "aws_secretsmanager_secret" "database_password_secret" {
  name = "/production/database/password/master"
}

// create a version of the secret (1) and set it to the randomly
// generated password done in the random_password module
resource "aws_secretsmanager_secret_version" "database_password_secret_version" {
  secret_id     = aws_secretsmanager_secret.database_password_secret.id
  secret_string = random_password.database_password.result
}

// create an IAM policy and attach it to the ecs_task_execution_role
// this policy will allow access to the secret which was created
// above. This will allow task defintions to set this as an environment
// variable when the container is executed
resource "aws_iam_role_policy" "password_policy_secretsmanager" {
  name = "password-policy-secretsmanager"

  // role_id this policy will be attached to
  role = aws_iam_role.ecs_task_execution_role.id

  // heredoc policy defintion
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_secretsmanager_secret.database_password_secret.arn}"
        ]
      }
    ]
  }
  EOF
}

// data source template file which defines the ECS task to be executed in ECS
// The key in this example passing the database_password parameter in the vars.
// It is pointing to the SSM vars. Within the JSON template, this is value gets
// inserted from here into the secrets section of the json file.
data "template_file" "task_template_secretsmanager" {
  template = file("./templates/task.json.tpl")

  vars = {
    app_cpu           = var.cpu
    app_memory        = var.memory
    database_password = aws_secretsmanager_secret.database_password_secret.arn
  }
}

// define the ECR task which will be run. This will be executed on an EC2
// cluster. Select any EC2 cluster at this point
resource "aws_ecs_task_definition" "task_definition_secretsmanager" {
  family                   = "task-secretsmanager"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["EC2"]
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  container_definitions    = data.template_file.task_template_secretsmanager.rendered
}
