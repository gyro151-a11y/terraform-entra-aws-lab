#!/usr/bin/env bash

# Check if the token source file exists before executing
if [ ! -f "saml_response.txt" ]; then
    echo "❌ Error: saml_response.txt not found in this directory!"
    echo "Please save your fresh Base64 token block into saml_response.txt first."
    return 1 2>/dev/null || exit 1
fi

echo "🔄 Contacting AWS Secure Token Service..."

# 1. Execute the exchange and capture the raw output into a variable
AWS_JSON_OUTPUT=$(aws sts assume-role-with-saml \
  --role-arn arn:aws:iam::629897139637:role/DevOps-Admin-Federated \
  --principal-arn arn:aws:iam::629897139637:saml-provider/DevOps-Lab-EntraID \
  --saml-assertion "$(cat saml_response.txt | tr -d '\n\r ')")

# 2. Check if the AWS command completed successfully
if [ $? -eq 0 ]; then
    # Extract and export each property natively into the environmental memory layout
    export AWS_ACCESS_KEY_ID=$(echo "$AWS_JSON_OUTPUT" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$AWS_JSON_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$AWS_JSON_OUTPUT" | jq -r '.Credentials.SessionToken')

    echo "✅ Keys successfully injected into terminal environment!"
    echo "Your session is live for the next 120 minutes. Running verification:"
    aws sts get-caller-identity --query "Arn" --output text

    # Clean up the token payload file automatically for security hygiene
    rm saml_response.txt
else
    echo "❌ AWS Authentication failed. Check your SAML token validity."
fi
