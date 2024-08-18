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

resource "aws_kinesis_stream" "data_stream" {
  name             = "terraform-kinesis-data-stream"
  shard_count      = 1
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Environment = "test"
  }
}


data "aws_iam_policy_document" "data-stream-policy" {
  statement {
    sid    = "1"
    effect = "Allow"

    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards",
    ]

    resources = [aws_kinesis_stream.data_stream.arn]
  }
}

resource "aws_kinesis_resource_policy" "data-stream-policy" {
  resource_arn = aws_kinesis_stream.data_stream.arn
  policy       = data.aws_iam_policy_document.data-stream-policy.json
}

module "lambda_function" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "data-stream-invoked-lambda"
  description   = "Lambda invoked by kinesis data stream"

  handler     = "bootstrap"                                          # The name of the Rust executable for Lambda
  runtime     = "provided.al2"                                       # Rust Lambdas use the custom Amazon Linux 2 runtime
  source_path = "${path.module}/kinesis-lambda/stream-consumers.zip" # Path to the compiled binary

  allowed_triggers = {
    KinesisStream = {
      service    = "kinesis.amazonaws.com"
      source_arn = aws_kinesis_stream.data_stream.arn
    }
  }

  event_source_mapping = [
    {
      event_source_arn  = aws_kinesis_stream.data_stream.arn
      starting_position = "LATEST"
      enabled           = true
    }
  ]

  tags = {
    Name = "data-stream-lambda"
  }
}

data "archive_file" "zip-lambda-source" {
  type        = "zip"
  source_file = "${path.module}/kinesis-lambda/stream-consumers.rs"
  output_path = "${path.module}/kinesis-lambda/stream-consumers.zip"
}
