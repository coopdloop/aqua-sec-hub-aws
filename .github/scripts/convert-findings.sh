#!/bin/bash

set -e  # Exit on error

# Enable debug logging
DEBUG=true

debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
    fi
}

process_findings() {
    local input_file=$1
    local output_file=$2
    local finding_type=$3
    local template=$4

    echo "=== Processing $finding_type findings ==="
    debug_log "Input file: $input_file"
    debug_log "Output file: $output_file"
    debug_log "Template: $template"

    if [ -f "$input_file" ]; then
        debug_log "Input file exists"

        if [ -n "$template" ]; then
            debug_log "Converting using template: $template"
            debug_log "Template content:"
            cat "$template"

            debug_log "Input file content:"
            cat "$input_file"

            if ! jq -f "$template" --arg AWS_REGION "$AWS_REGION" --arg AWS_ACCOUNT_ID "$AWS_ACCOUNT_ID" "$input_file" > "${output_file}.tmp"; then
                echo "ERROR: Failed to convert findings using template for $finding_type"
                return 1
            fi
            mv "${output_file}.tmp" "$input_file"
            debug_log "Conversion complete"
        fi

        debug_log "Counting findings..."
        local findings_count=$(jq '.Findings | length' "$input_file")
        echo "Found $findings_count findings"

        if [ "$findings_count" -gt 0 ]; then
            debug_log "Creating formatted JSON..."
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

            debug_log "Final output content:"
            cat "$output_file"

            echo "Importing $findings_count findings to Security Hub..."
            debug_log "AWS Region: $AWS_REGION"
            debug_log "AWS Account ID: $AWS_ACCOUNT_ID"

            # Test AWS CLI credentials
            debug_log "Testing AWS credentials..."
            aws sts get-caller-identity

            # Import findings with debug
            set -x  # Enable command printing
            aws securityhub batch-import-findings --cli-input-json "file://$output_file"
            set +x  # Disable command printing
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
echo "Starting findings processing..."
debug_log "Current directory: $(pwd)"
debug_log "Listing files:"
ls -la

process_findings "report.asff" "vuln-findings.json" "Vulnerabilities"

if [ -f "iac-report.json" ]; then
    process_findings "iac-report.json" "iac-findings.json" "Infrastructure/Misconfigurations" ".github/templates/iac-to-asff.jq"
fi

if [ -f "secrets-report.json" ]; then
    process_findings "secrets-report.json" "secrets-findings.json" "Secrets/Exposed" ".github/templates/secrets-to-asff.jq"
fi
