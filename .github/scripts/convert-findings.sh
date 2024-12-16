#!/bin/bash
set -e  # Exit on error

DEBUG=true

debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
    fi
}

validate_json() {
    local file=$1
    if jq empty "$file" 2>/dev/null; then
        debug_log "JSON validation passed for $file"
        return 0
    else
        debug_log "JSON validation failed for $file"
        return 1
    fi
}

send_to_security_hub() {
    local file=$1
    local temp_file="temp_findings.json"

    # Format the findings using jq to handle escaping and formatting
    jq -c --arg account "$AWS_ACCOUNT_ID" --arg region "$AWS_REGION" '{
        Findings: [.Findings[] | {
            SchemaVersion,
            Id,
            # Use global product ARN format
            ProductArn: "arn:aws:securityhub:\($region)::product/aquasecurity/aquasecurity",
            GeneratorId,
            AwsAccountId: $account,
            Types,
            CreatedAt,
            UpdatedAt,
            Severity,
            Title,
            Description: (.Description | gsub("\n";" ")),
            Resources: [.Resources[] | {
                Type,
                Id,
                Partition,
                Region: $region
            }],
            RecordState
        }]
    }' "$file" > "$temp_file"

    debug_log "Attempting to send findings..."
    debug_log "Content of findings file:"
    jq '.' "$temp_file"  # Pretty print for debug

    aws securityhub batch-import-findings --cli-input-json "file://$temp_file"

    rm -f "$temp_file"
}

# Rest of the script remains the same
process_findings() {
    local input_file=$1
    local output_file=$2
    local finding_type=$3
    local template=$4

    echo "=== Processing $finding_type findings ==="
    debug_log "Input file: $input_file"
    debug_log "Output file: $output_file"

    if [ -f "$input_file" ]; then
        debug_log "Input file exists"

        if [ -n "$template" ]; then
            debug_log "Converting using template: $template"

            jq -c -f "$template" \
               --arg AWS_REGION "$AWS_REGION" \
               --arg AWS_ACCOUNT_ID "$AWS_ACCOUNT_ID" \
               "$input_file" > "$output_file"

            if ! validate_json "$output_file"; then
                echo "ERROR: Failed to create valid JSON output"
                return 1
            fi
        fi

        debug_log "Importing findings to Security Hub..."
        send_to_security_hub "$output_file"
    else
        echo "No $finding_type findings file found at $input_file"
    fi
}

echo "Starting findings processing..."
debug_log "Current directory: $(pwd)"
debug_log "Listing files:"
ls -la

# Process vulnerability findings (direct ASFF format)
if [ -f "report.asff" ]; then
    debug_log "Processing vulnerability report..."
    if validate_json "report.asff"; then
        send_to_security_hub "report.asff"
    else
        echo "ERROR: Invalid JSON in report.asff"
        exit 1
    fi
fi

# Process IaC findings
if [ -f "iac-report.json" ]; then
    process_findings \
        "iac-report.json" \
        "iac-findings.asff" \
        "Infrastructure/Misconfigurations" \
        ".github/templates/iac-to-asff.jq"
fi

# Process secrets findings
if [ -f "secrets-report.json" ]; then
    process_findings \
        "secrets-report.json" \
        "secrets-findings.asff" \
        "Secrets/Exposed" \
        ".github/templates/secrets-to-asff.jq"
fi
