# Execute the assume-role command, parse the output, and export variables instantly
eval $(aws sts assume-role \
  --role-arn "arn:aws:iam::629897139637:role/IAM-Security-Manager" \
  --role-session-name "IdentityBootstrapSession" \
  --output json | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)"')

  # After running this script, your terminal session will have the temporary credentials set as environment variables, allowing you to interact with AWS services using the assumed role's permissions.
  # This assumed role allows for OpenID Connect (OIDC) federation, enabling secure access to AWS resources without the need for long-term credentials.

  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  # Run this unset command to clear the temporary credentials from your environment when you're done, ensuring that your session is secure and doesn't retain access to AWS resources longer than necessary.

  aws sts get-caller-identity

  # Run this command to verify what AWS identity you are currently authenticated as, which should either be empty (if you haven't assumed the role) or show the ARN of the assumed role, confirming that the temporary credentials are in effect.