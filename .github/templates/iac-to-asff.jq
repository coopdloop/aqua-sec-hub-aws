# Format time in ISO 8601 format
def format_time:
  now | strftime("%Y-%m-%dT%H:%M:%SZ");

{
  "Findings": [
    .Results[] | select(.Misconfigurations != null) | .Misconfigurations[] | {
      "SchemaVersion": "2018-10-08",
      "Id": (.ID + "-" + (now | tostring)),
      "ProductArn": ("arn:aws:securityhub:" + $AWS_REGION + "::product/aquasecurity/aquasecurity"),
      "GeneratorId": ("Trivy/" + .ID),
      "AwsAccountId": $AWS_ACCOUNT_ID,
      "Types": ["Software and Configuration Checks/Infrastructure Misconfigurations"],
      "CreatedAt": format_time,
      "UpdatedAt": format_time,
      "Severity": {
        "Label": .Severity
      },
      "Title": .Title,
      "Description": .Description,
      "Resources": [{
        "Type": "Infrastructure",
        "Id": .ID,
        "Partition": "aws",
        "Region": $AWS_REGION
      }],
      "RecordState": "ACTIVE"
    }
  ]
}
