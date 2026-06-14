# 🔍 Hardened Metric Filter that completely ignores background VPC Flow Logs
resource "aws_cloudwatch_log_metric_filter" "nginx_5xx_filter" {
  name           = "nginx-5xx-error-filter"
  log_group_name = "/ecs/devops-lab-app"

  # 🎯 Searches for lines with GET or POST followed by a 5xx status, while ignoring flow logs
  pattern = "\"GET\" \" 50\" -eni- -ACCEPT -REJECT"

  metric_transformation {
    name      = "HTTP5xxErrorCount"
    namespace = "DevOpsLab/Application"
    value     = "1"
  }
}

# ⏰ Alarm that fires if more than two 5XX errors occur within a 1-minute window
resource "aws_cloudwatch_metric_alarm" "nginx_5xx_alarm" {
  alarm_name          = "app-high-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTP5xxErrorCount"
  namespace           = "DevOpsLab/Application"
  period              = "60" # 1 minute evaluation window
  statistic           = "Sum"
  threshold           = "2"
  alarm_description   = "This alarm fires if the web app drops multiple 5XX responses in a single minute."
  treat_missing_data  = "notBreaching"
}

# 🔑 1. Create a Dedicated Customer Managed KMS Key for the Lab
resource "aws_kms_key" "sns_encryption_key" {
  description             = "Customer managed KMS key for encrypting high-priority application SNS topics"
  deletion_window_in_days = 7
  enable_key_rotation     = true # 🔐 Compliance gold standard: Automatic annual key rotation

  # 📑 Standard baseline key policy allowing the root account to manage it
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { "AWS" = "arn:aws:iam::629897139637:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow EventBridge to Use the Key"
        Effect    = "Allow"
        Principal = { "Service" = "events.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 🏷️ 2. Create a clean Alias for the Customer Key
resource "aws_kms_alias" "sns_key_alias" {
  name          = "alias/devops-lab-sns-key"
  target_key_id = aws_kms_key.sns_encryption_key.key_id
}

# 📡 3. The Fully Compliant SNS Topic
resource "aws_sns_topic" "devops_alerts" {
  name              = "devops-lab-application-alerts"
  kms_master_key_id = aws_kms_alias.sns_key_alias.name # 🎯 Hardened with your own CMK!
}

# 🎭 EventBridge Rule watching for our specific Alarm flipping to an 'ALARM' state
resource "aws_cloudwatch_event_rule" "alarm_remediation_rule" {
  name        = "catch-app-5xx-alarm-state"
  description = "Triggers automatically when the application 5XX error alarm activates."

  event_pattern = jsonencode({
    "source" : ["aws.cloudwatch"],
    "detail-type" : ["CloudWatch Alarm State Change"],
    "resources" : ["${aws_cloudwatch_metric_alarm.nginx_5xx_alarm.arn}"],
    "detail" : {
      "state" : {
        "value" : ["ALARM"]
      }
    }
  })
}

# 🎯 Route the EventBridge payload directly to the SNS Topic
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.alarm_remediation_rule.name
  target_id = "SendToSNSTopic"
  arn       = aws_sns_topic.devops_alerts.arn
}

# 🔐 Access Policy allowing EventBridge to publish alerts into your SNS Topic
resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.devops_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.devops_alerts.arn
      }
    ]
  })
}