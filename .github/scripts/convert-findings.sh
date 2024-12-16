#!/bin/bash

# Create templates directory
mkdir -p templates

# Create IaC conversion template
cat << 'EOF' > templates/iac-to-asff.jq
{
  "Findings": [
    .Results[] | select(.Misconfigurations != null) | .Misconfigurations[] | {
      "SchemaVersion": "2018-10-08",
      "Id": (.ID + "-" + (now | tostring)),
      "ProductArn": ("arn:aws:securityhub:" + env.AWS_REGION + "::" + env.AWS_ACCOUNT_ID + ":product/aquasecurity/aquasecurity"),
      "GeneratorId": ("Trivy/" + .ID),
      "AwsAccountId": env.AWS_ACCOUNT_ID,
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
          "Text": .Resolution
        }
      },
      "Resources": [{
        "Type": "Infrastructure",
        "Id": .ID,
        "Partition": "aws",
        "Region": env.AWS_REGION
      }],
      "RecordState": "ACTIVE"
    }
  ]
}
EOF

# Create secrets conversion template
cat << 'EOF' > templates/secrets-to-asff.jq
{
  "Findings": [
    .Results[] | select(.Secrets != null) | .Secrets[] | {
      "SchemaVersion": "2018-10-08",
      "Id": (.RuleID + "-" + (now | tostring)),
      "ProductArn": ("arn:aws:securityhub:" + env.AWS_REGION + "::" + env.AWS_ACCOUNT_ID + ":product/aquasecurity/aquasecurity"),
      "GeneratorId": ("Trivy/" + .RuleID),
      "AwsAccountId": env.AWS_ACCOUNT_ID,
      "Types": ["Sensitive Data Identifications"],
      "CreatedAt": (now | tostring),
      "UpdatedAt": (now | tostring),
      "Severity": {
        "Label": "HIGH"
      },
      "Title": ("Secret found: " + .Title),
      "Description": ("Found secret in " + .Match),
      "Resources": [{
        "Type": "Secret",
        "Id": .RuleID,
        "Partition": "aws",
        "Region": env.AWS_REGION
      }],
      "RecordState": "ACTIVE"
    }
  ]
}
EOF

# Process findings function
process_findings() {
    local input_file=$1
    local output_file=$2
    local finding_type=$3

    if [ -f "$input_file" ]; then
        echo "Processing $finding_type findings..."

        # Create properly formatted JSON
        jq --arg account "$AWS_ACCOUNT_ID" \
           --arg region "$AWS_REGION" \
           --arg type "$finding_type" '
          .Findings = [.Findings[] |
            . + {
              AwsAccountId: $account,
              Region: $region,
              Description: (.Description | gsub("\n";" ")),
              RecordState: "ACTIVE",
              Types: ["Software and Configuration Checks/" + $type]
            }
          ]' "$input_file" > "$output_file"

        # Import to Security Hub
        aws securityhub batch-import-findings --cli-input-json "file://$output_file"
    fi
}

# Process all finding types
process_findings "report.asff" "vuln-findings.json" "Vulnerabilities"

if [ -f "iac-report.json" ]; then
    jq -f templates/iac-to-asff.jq iac-report.json > iac.asff
    process_findings "iac.asff" "iac-findings.json" "Infrastructure/Misconfigurations"
fi

if [ -f "secrets-report.json" ]; then
    jq -f templates/secrets-to-asff.jq secrets-report.json > secrets.asff
    process_findings "secrets.asff" "secrets-findings.json" "Secrets/Exposed"
fi
