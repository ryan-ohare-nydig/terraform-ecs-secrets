# Terraform ECS Secrets

Store secrets on Parameter Store vs AWS Secrets Manager and inject them into Amazon ECS tasks using Terraform.

## Running the Terraform

To run this terraform, if STS is enabled, a helper script [sts-setenv.sh](sts-setenv.sh) has been included to set environment variables easily from the AWS sts session.

### sts-setenv

Usage: ```sts-setenv.sh <aws_profile_name>```

### Building with STS

```bash
alias tf=terraform
source sts-setenv.sh default
tf init
tf plan \ 
    -var aws_session_token=AWS_SESSION_TOKEN \
    -var aws_access_key=AWS_ACCESS_KEY \
    -var aws_secret_key=AWS_SECRET_KEY

tf apply \
    -var aws_session_token=AWS_SESSION_TOKEN \
    -var aws_access_key=AWS_ACCESS_KEY \
    -var aws_secret_key=AWS_SECRET_KEY
```
### Building w/o STS

```bash
alias tf=terraform
export AWS_ACCESS_KEY="<aws_access_key>"
export AWS_SECRET_KEY="<aws_secret_key>"

tf init
tf plan \ 
    -var aws_access_key=AWS_ACCESS_KEY \
    -var aws_secret_key=AWS_SECRET_KEY

tf apply \
    -var aws_access_key=AWS_ACCESS_KEY \
    -var aws_secret_key=AWS_SECRET_KEY
```
## Generating a Secret

In this example, a secret is generated randomly using the random module for TF. *Using TF to populate secrets is a bad idea*. For this example however, it works just fine. This could also be adopted in a dev environment where secrets cannot be used to compromise meaningful data.

#### provider.tf

Include the random provider
```terraform
provider "random" {}
```

#### secretsmanager.tf

In this section, a database secret is created in the secrets manager at path "/production/database/password/master". Then, the secret is given an value which is generated randomly.

```terraform
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
```

## Create Roles and Policies for Secrets Access

Now, IAM policies will be defined which allow read access to the specified secret. This policy will need to be attached to an execution roles for the ECS container to run under so it can access the secret. A new ECS execution role will be setup specifically for this example. For the execution role, an assume-role policy is created to allow the execution policy to execute ECS on EC2.

#### main.tf

This section creates a policy allowing a role to assume that of ecs tasks which is required to execute and ECS container. After that, a an execution role is create to which the policy is attached. ECS tasks will run as this role. Later, this role will have the secrets policy attached to it as well. Additionally, the main ECS task role will be assigned to this role to make it identical to the built in default policy for ECS.
```terraform
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

// make an IAM role for the task to to run under. Base will have have only the ecs
// task execution policy (same as the default role) and this will be set as an
// assume role policy
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution"

  // allow this task to assume the role of ecs services
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json
  path               = "/"
}

// default task execution policy used for ECS tasks.
// By default it is attached to ecsTaskExecutionRole which is the default role used in
// ECS tasks
data "aws_iam_policy" "ecs_task_execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution.arn
}
```

#### secretsmanager.tf

Create the IAM policy which will allow access to the secret and attach it to the role created above for the task to run under.
```terraform
// create an IAM policy and attach it to the ecs_task_execution_role
// this policy will allow access to the secret which was created
// above. This will allow task definitions to set this as an environment
// variable when the container is executed
resource "aws_iam_role_policy" "password_policy_secretsmanager" {
  name = "password-policy-secretsmanager"

  // role_id this policy will be attached to
  role = aws_iam_role.ecs_task_execution_role.id

  // heredoc policy definition
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
```

## Define ECS Task

ECS tasks are defined as json and make use of the template terraform module to allow the injection of the secrets generated ARN into the template.

#### provider.tf

Include the template provider.
```terraform
# Template provider
// this is needed to template the json for
// the ECR task definition
provider "template" {}
```

#### secretsmanager.tf

Create the template file as a data source which will be used later to populate the actual task definition.
```terraform
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
```

#### templates/task.json.tpl

Template JSON file for the task definition. Templated out variables for container resource specs and the database password.
```json
[
  {
    "name": "secrets-application",
    "image": "httpd:2.4",
    "cpu": ${app_cpu},
    "memory": ${app_memory},
    "essential": true,
    "secrets": [
      {
        "name": "PASSWORD",
        "valueFrom": "${database_password}"
      }
    ]
  }
]
```

## Create the Task Definition

Now with all the infrastructure built, an ECS task can be defined to run the specific image.

#### secretsmanager.tf

This will create the ECS task. Once complete, this task will be runnable on any ECS cluster in the AWS account.
```terraform
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
```

## References

https://www.sufle.io/blog/keeping-secrets-as-secret-on-amazon-ecs-using-terraform