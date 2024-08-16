terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "sample-lambda-role"
  }
}

resource "aws_iam_policy" "lambda-policy" {
  name        = "lambda_policy"
  path        = "/"
  description = "Policy to perform lambda deployment using terraform."
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "role-policy-attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda-policy.arn
}

# Archive a single file.

data "archive_file" "zip-lambda-source" {
  type        = "zip"
  source_file = "${path.module}/sample/hello.py"
  output_path = "${path.module}/sample/hello.zip"
}

resource "aws_lambda_function" "my_lambda" {
  filename      = "${path.module}/sample/hello.zip"
  function_name = "my-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "hello.my_lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.role-policy-attachment]
}

output "role" {
  value = aws_iam_role.lambda_role.name
}

output "role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "policy_arn" {
  value = aws_iam_policy.lambda-policy.arn
}
