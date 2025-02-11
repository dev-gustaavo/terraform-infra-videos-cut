output "s3_bucket_name" {
  value = aws_s3_bucket.videos_cut.bucket
}

output "sqs_url" {
  value = aws_sqs_queue.video_cut_queue.url
}

output "lambda_function_name" {
  value = aws_lambda_function.lambda_videos_cut.function_name
}

output "sns_arn" {
  value = aws_sns_topic.video_processing_errors.arn
}