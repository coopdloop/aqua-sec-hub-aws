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
            debug_log "Template content:"
            cat "$template"

            # Convert to ASFF format using template
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
        debug_log "Content being sent:"
        cat "$output_file"

        # Ensure JSON is properly formatted and compact
        jq -c '.' "$output_file" | aws securityhub batch-import-findings --findings file:///dev/stdin
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
        jq -c '.' report.asff | aws securityhub batch-import-findings --findings file:///dev/stdin
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
