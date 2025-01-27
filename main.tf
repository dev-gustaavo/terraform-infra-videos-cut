provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "videos_cut" {
  bucket = "videos-cut"
}

resource "aws_sqs_queue" "video_cut_queue" {
  name = "video-cut-queue"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-videos-cut-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-videos-cut-policy"
  description = "Permissão para Lambda manipular arquivos no S3 e publicar no SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "sqs:SendMessage"
        ],
        Resource = [
          aws_s3_bucket.videos_cut.arn,
          "${aws_s3_bucket.videos_cut.arn}/*",
          aws_sqs_queue.video_cut_queue.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = "logs:*",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_role_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "lambda_videos_cut" {
  function_name = "lambda-videos-cut-send-sqs"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "video_cut.lambda_handler"
  runtime       = "python3.9"

  filename         = "${path.module}/lambda/video_cut.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/video_cut.zip")

  environment {
    variables = {
      SQS_URL = aws_sqs_queue.video_cut_queue.url
    }
  }
}

resource "aws_s3_bucket_notification" "s3_event" {
  bucket = aws_s3_bucket.videos_cut.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_videos_cut.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".mp4"
  }
}

resource "aws_lambda_permission" "s3_permission" {
  statement_id  = "AllowS3Event"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_videos_cut.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.videos_cut.arn
}
