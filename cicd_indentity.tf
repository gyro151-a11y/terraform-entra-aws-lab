data "aws_caller_identity" "current" {}

# 1. Define the execution role that the GitHub Actions runner will dynamically assume
resource "aws_iam_role" "github_actions_role" {
  name        = "devops-lab-github-actions-role"
  description = "Assumed by GitHub Actions workflow for zero-trust automated deployments"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { 
          # Points directly to the global anchor you just built via the CLI!
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com" 
        }
        Action    = "sts:AssumeRoleWithWebIdentity"
        
        Condition = {
          StringEquals = {
            # Zero Trust Validation: Token audience must match the AWS STS endpoint
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Zero Trust Validation: Lock deployment rights strictly to YOUR repo and main branch
            # ⚠️ REMEMBER: Swap out YOUR_GITHUB_USERNAME with your real GitHub handle
            "token.actions.githubusercontent.com:sub" = "repo:gyro151-a11y/terraform-entra-aws-lab:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# 2. Attach administrative permissions so the role can provision your lab tiers
resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}