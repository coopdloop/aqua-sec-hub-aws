# templates/iac-to-asff.jq
{
  "Findings": [
    .Results[] | select(.Misconfigurations != null) | .Misconfigurations[] | {
      "SchemaVersion": "2018-10-08",
      "Id": (.ID + "-" + (now | tostring)),
      "ProductArn": "arn:aws:securityhub:\($ENV.AWS_REGION)::\($ENV.AWS_ACCOUNT_ID):product/aquasecurity/aquasecurity",
      "GeneratorId": "Trivy/\(.ID)",
      "AwsAccountId": $ENV.AWS_ACCOUNT_ID,
      "Types": ["Software and Configuration Checks/Infrastructure Misconfigurations"],
      "CreatedAt": (now | tostring),
      "UpdatedAt": (now | tostring),
      "Severity": {
        "Label": .Severity
      },
      "Title": .Title,
      "Description": .Description,
      "Remediation": {
        "Recommendation": {
          "Text": .Resolution,
          "Url": .References[0]
        }
      },
      "Resources": [{
        "Type": "Infrastructure",
        "Id": .ID,
        "Partition": "aws",
        "Region": $ENV.AWS_REGION
      }],
      "RecordState": "ACTIVE"
    }
  ]
}
