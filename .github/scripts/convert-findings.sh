#!/bin/bash

set -e  # Exit on error

# Process findings function
process_findings() {
    local input_file=$1
    local output_file=$2
    local finding_type=$3
    local template=$4

    echo "Processing $finding_type findings..."

    if [ -f "$input_file" ]; then
        if [ -n "$template" ]; then
            # Convert using template first
            if ! jq -f "$template" --arg AWS_REGION "$AWS_REGION" --arg AWS_ACCOUNT_ID "$AWS_ACCOUNT_ID" "$input_file" > "${output_file}.tmp"; then
                echo "Failed to convert findings using template for $finding_type"
                return 1
            fi
            mv "${output_file}.tmp" "$input_file"
        fi

        # Check if file has findings
        local findings_count=$(jq '.Findings | length' "$input_file")
        if [ "$findings_count" -gt 0 ]; then
            # Create properly formatted JSON
            jq --arg account "$AWS_ACCOUNT_ID" \
               --arg region "$AWS_REGION" \
               --arg type "$finding_type" \
               '.Findings = [.Findings[] |
                  . + {
                    AwsAccountId: $account,
                    Region: $region,
                    Description: (if .Description then .Description | gsub("\n";" ") else "" end),
                    RecordState: "ACTIVE",
                    Types: ["Software and Configuration Checks/" + $type]
                  }
                ]' "$input_file" > "$output_file"

            echo "Importing $findings_count findings to Security Hub..."
            aws securityhub batch-import-findings --cli-input-json "file://$output_file"
        else
            echo "No findings to report for $finding_type"
        fi
    else
        echo "No $finding_type findings file found at $input_file"
    fi
}

# Create templates directory if it doesn't exist
mkdir -p .github/templates

# Create IaC conversion template
cat << 'EOF' > .github/templates/iac-to-asff.jq
{
  "Findings": [
    .Results[] | select(.Misconfigurations != null) | .Misconfigurations[] | select(. != null) | {
      "SchemaVersion": "2018-10-08",
      "Id": (.ID + "-" + (now | tostring)),
      "ProductArn": ("arn:aws:securityhub:" + $AWS_REGION + "::" + $AWS_ACCOUNT_ID + ":product/aquasecurity/aquasecurity"),
      "GeneratorId": ("Trivy/" + .ID),
      "AwsAccountId": $AWS_ACCOUNT_ID,
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
        "Region": $AWS_REGION
      }],
      "RecordState": "ACTIVE"
    }
  ]
}
EOF

# Create secrets conversion template
cat << 'EOF' > .github/templates/secrets-to-asff.jq
{
  "Findings": [
    .Results[] | select(.Secrets != null) | .Secrets[] | select(. != null) | {
      "SchemaVersion": "2018-10-08",
      "Id": (.RuleID + "-" + (now | tostring)),
      "ProductArn": ("arn:aws:securityhub:" + $AWS_REGION + "::" + $AWS_ACCOUNT_ID + ":product/aquasecurity/aquasecurity"),
      "GeneratorId": ("Trivy/" + .RuleID),
      "AwsAccountId": $AWS_ACCOUNT_ID,
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
        "Region": $AWS_REGION
      }],
      "RecordState": "ACTIVE"
    }
  ]
}
EOF

# Process all finding types
process_findings "report.asff" "vuln-findings.json" "Vulnerabilities"

if [ -f "iac-report.json" ]; then
    process_findings "iac-report.json" "iac-findings.json" "Infrastructure/Misconfigurations" ".github/templates/iac-to-asff.jq"
fi

if [ -f "secrets-report.json" ]; then
    process_findings "secrets-report.json" "secrets-findings.json" "Secrets/Exposed" ".github/templates/secrets-to-asff.jq"
fi
