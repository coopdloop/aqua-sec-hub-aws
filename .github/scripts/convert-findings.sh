#!/bin/bash

set -e  # Exit on error

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

    if [ -f "$input_file" ]; then
        debug_log "Input file exists"

        if [ -n "$template" ]; then
            debug_log "Converting using template..."
            if ! jq -f "$template" --arg AWS_REGION "$AWS_REGION" --arg AWS_ACCOUNT_ID "$AWS_ACCOUNT_ID" "$input_file" > "${output_file}"; then
                echo "ERROR: Failed to convert findings using template for $finding_type"
                return 1
            fi
        fi

        debug_log "Importing findings to Security Hub..."
        debug_log "Content being sent:"
        cat "${output_file}"

        # Use --findings instead of --cli-input-json to match original working version
        aws securityhub batch-import-findings --findings "file://${output_file}"
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
    aws securityhub batch-import-findings --findings "file://report.asff"
fi

# Process IaC findings
if [ -f "iac-report.json" ]; then
    process_findings "iac-report.json" "iac-findings.asff" "Infrastructure/Misconfigurations" ".github/templates/iac-to-asff.jq"
fi

# Process secrets findings
if [ -f "secrets-report.json" ]; then
    process_findings "secrets-report.json" "secrets-findings.asff" "Secrets/Exposed" ".github/templates/secrets-to-asff.jq"
fi
