# 🔍 Metric Filter to detect 5XX Server Errors in the Nginx App Logs
resource "aws_cloudwatch_log_metric_filter" "nginx_5xx_filter" {
  name           = "nginx-5xx-error-filter"
  pattern        = "[ip, id, user, timestamp, request, status = 5*, bytes_sent]"
  log_group_name = "/ecs/devops-lab-app" # 👈 Taps directly into your existing log stream

  metric_transformation {
    name      = "HTTP5xxErrorCount"
    namespace = "DevOpsLab/Application"
    value     = "1" # Every time a log line matches, increment the counter by 1
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

# 📡 Create the SNS Notification Topic for the DevOps Response Team
resource "aws_sns_topic" "devops_alerts" {
  name              = "devops-lab-application-alerts"
  kms_master_key_id = "alias/aws/sns" # 🔐 Encrypts the topic payloads using AWS-managed KMS
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