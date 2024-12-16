# Format time in ISO 8601 format
def format_time:
  now | strftime("%Y-%m-%dT%H:%M:%SZ");

{
  "Findings": [
    .Results? // [] |
    if type == "array" then
      .[] | select(.Secrets != null) | .Secrets[] | select(. != null) | {
        "SchemaVersion": "2018-10-08",
        "Id": (.RuleID + "-" + (now | tostring)),
        "ProductArn": ("arn:aws:securityhub:" + $AWS_REGION + "::product/aquasecurity/aquasecurity"),
        "GeneratorId": ("Trivy/" + .RuleID),
        "AwsAccountId": $AWS_ACCOUNT_ID,
        "Types": ["Sensitive Data Identifications"],
        "CreatedAt": format_time,
        "UpdatedAt": format_time,
        "Severity": {
          "Label": "HIGH"
        },
        "Title": ("Secret found: " + .Title),
        "Description": ("Found secret in " + .Match),
        "Resources": [{
          "Type": "Secret",
          "Id": .RuleID,
          "Partition": "aws",
          "Region": $AWS_REGION
        }],
        "RecordState": "ACTIVE"
      }
    else
      empty
    end
  ]
}
