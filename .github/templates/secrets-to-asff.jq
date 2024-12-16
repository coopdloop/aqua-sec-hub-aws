# templates/secrets-to-asff.jq
{
  "Findings": [
    .Results[] | select(.Secrets != null) | .Secrets[] | {
      "SchemaVersion": "2018-10-08",
      "Id": (.RuleID + "-" + (now | tostring)),
      "ProductArn": "arn:aws:securityhub:\($ENV.AWS_REGION)::\($ENV.AWS_ACCOUNT_ID):product/aquasecurity/aquasecurity",
      "GeneratorId": "Trivy/\(.RuleID)",
      "AwsAccountId": $ENV.AWS_ACCOUNT_ID,
      "Types": ["Sensitive Data Identifications"],
      "CreatedAt": (now | tostring),
      "UpdatedAt": (now | tostring),
      "Severity": {
        "Label": "HIGH"
      },
      "Title": "Secret found: \(.Title)",
      "Description": "Found secret in \(.Match)",
      "Resources": [{
        "Type": "Secret",
        "Id": .RuleID,
        "Partition": "aws",
        "Region": $ENV.AWS_REGION
      }],
      "RecordState": "ACTIVE"
    }
  ]
}
