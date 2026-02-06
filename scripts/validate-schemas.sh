#!/bin/bash
#
# Validate YAML files against JSON schemas.
#
# Usage:
#   ./scripts/validate-schemas.sh [--json] [path...]
#
# If no paths given, validates all specs, postures, and manifests.
# Requires: python3, python3-yaml, python3-jsonschema
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

# Colors (disabled if not a terminal or --json)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

JSON_OUTPUT=false
PATHS=()
FAILED=0
PASSED=0
ERRORS=0

usage() {
    echo "Usage: $(basename "$0") [--json] [path...]"
    echo ""
    echo "Validate YAML files against their JSON schemas."
    echo ""
    echo "Options:"
    echo "  --json     Output results as JSON"
    echo "  --help     Show this help"
    echo ""
    echo "If no paths given, validates all:"
    echo "  v2/specs/*.yaml       against v2/defs/spec.schema.json"
    echo "  v2/postures/*.yaml    against v2/defs/posture.schema.json"
    echo "  manifests/*.yaml      against v2/defs/manifest.schema.json"
    echo ""
    echo "Exit codes:"
    echo "  0  All files valid"
    echo "  1  One or more files invalid"
    echo "  2  Error (missing schema, missing dependency, etc.)"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_OUTPUT=true; shift ;;
        --help|-h) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) PATHS+=("$1"); shift ;;
    esac
done

# Disable colors for non-terminal or JSON output
if [[ ! -t 1 ]] || [[ "$JSON_OUTPUT" == "true" ]]; then
    RED='' GREEN='' YELLOW='' NC=''
fi

# Check dependencies
if ! python3 -c "import jsonschema" 2>/dev/null; then
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo '{"error": "python3-jsonschema not installed. Run: apt install python3-jsonschema"}'
    else
        echo -e "${RED}python3-jsonschema not installed.${NC} Run: apt install python3-jsonschema" >&2
    fi
    exit 2
fi

# Map: given a YAML file path, determine which schema to use
resolve_schema() {
    local file_path="$1"
    local abs_path
    abs_path="$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")"

    local rel_path="${abs_path#"$SITE_CONFIG_DIR/"}"

    case "$rel_path" in
        v2/specs/*.yaml)     echo "$SITE_CONFIG_DIR/v2/defs/spec.schema.json" ;;
        v2/postures/*.yaml)  echo "$SITE_CONFIG_DIR/v2/defs/posture.schema.json" ;;
        manifests/*.yaml)    echo "$SITE_CONFIG_DIR/v2/defs/manifest.schema.json" ;;
        *)
            # Try to infer from sibling defs/ directory
            local dir
            dir="$(dirname "$abs_path")"
            local schema_path="${dir}/../defs/spec.schema.json"
            if [[ -f "$schema_path" ]]; then
                echo "$schema_path"
            else
                echo ""
            fi
            ;;
    esac
}

# Validate a single file
validate_file() {
    local file_path="$1"
    local schema_path="$2"

    local result
    result=$(python3 -c "
import sys, json, yaml
from jsonschema import validate, ValidationError, SchemaError

spec_path = sys.argv[1]
schema_path = sys.argv[2]

try:
    with open(schema_path) as f:
        schema = json.load(f)
except Exception as e:
    print(json.dumps({'valid': False, 'path': spec_path, 'error': f'Failed to load schema: {e}'}))
    sys.exit(2)

try:
    with open(spec_path) as f:
        spec = yaml.safe_load(f)
except Exception as e:
    print(json.dumps({'valid': False, 'path': spec_path, 'error': f'Failed to load YAML: {e}'}))
    sys.exit(2)

try:
    validate(instance=spec, schema=schema)
    print(json.dumps({'valid': True, 'path': spec_path}))
    sys.exit(0)
except ValidationError as e:
    error_path = '.'.join(str(p) for p in e.absolute_path) if e.absolute_path else '(root)'
    print(json.dumps({'valid': False, 'path': spec_path, 'error': e.message, 'location': error_path}))
    sys.exit(1)
except SchemaError as e:
    print(json.dumps({'valid': False, 'path': spec_path, 'error': f'Invalid schema: {e.message}'}))
    sys.exit(2)
" "$file_path" "$schema_path" 2>&1) && local exit_code=0 || local exit_code=$?

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$result"
    else
        local valid
        valid=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('valid', False))" 2>/dev/null || echo "false")
        if [[ "$valid" == "True" ]]; then
            echo -e "  ${GREEN}✓${NC} $file_path"
            ((PASSED++))
        elif [[ $exit_code -eq 2 ]]; then
            local error
            error=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
            echo -e "  ${RED}✗${NC} $file_path"
            echo "    Error: $error"
            ((ERRORS++))
        else
            local error location
            error=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error', 'Unknown error'))" 2>/dev/null || echo "Unknown error")
            location=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('location', ''))" 2>/dev/null || echo "")
            echo -e "  ${RED}✗${NC} $file_path"
            if [[ -n "$location" && "$location" != "(root)" ]]; then
                echo "    Location: $location"
            fi
            echo "    Error: $error"
            ((FAILED++))
        fi
    fi

    return $exit_code
}

# Main logic
cd "$SITE_CONFIG_DIR"

if [[ ${#PATHS[@]} -gt 0 ]]; then
    # Validate specific files
    overall_exit=0
    for path in "${PATHS[@]}"; do
        if [[ ! -f "$path" ]]; then
            if [[ "$JSON_OUTPUT" == "true" ]]; then
                echo "{\"valid\": false, \"path\": \"$path\", \"error\": \"File not found\"}"
            else
                echo -e "  ${RED}✗${NC} $path (not found)"
            fi
            ((ERRORS++))
            overall_exit=2
            continue
        fi

        schema=$(resolve_schema "$path")
        if [[ -z "$schema" || ! -f "$schema" ]]; then
            if [[ "$JSON_OUTPUT" == "true" ]]; then
                echo "{\"valid\": false, \"path\": \"$path\", \"error\": \"Cannot determine schema for this file\"}"
            else
                echo -e "  ${YELLOW}?${NC} $path (no schema found, skipped)"
            fi
            continue
        fi

        validate_file "$path" "$schema" || overall_exit=$?
    done
else
    # Validate all known schema-backed files
    overall_exit=0

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo "Validating schemas..."
    fi

    # Specs
    if ls v2/specs/*.yaml 1>/dev/null 2>&1; then
        [[ "$JSON_OUTPUT" != "true" ]] && echo ""
        [[ "$JSON_OUTPUT" != "true" ]] && echo "Specs (v2/defs/spec.schema.json):"
        for f in v2/specs/*.yaml; do
            validate_file "$f" "v2/defs/spec.schema.json" || overall_exit=$?
        done
    fi

    # Postures
    if ls v2/postures/*.yaml 1>/dev/null 2>&1; then
        [[ "$JSON_OUTPUT" != "true" ]] && echo ""
        [[ "$JSON_OUTPUT" != "true" ]] && echo "Postures (v2/defs/posture.schema.json):"
        for f in v2/postures/*.yaml; do
            validate_file "$f" "v2/defs/posture.schema.json" || overall_exit=$?
        done
    fi

    # Manifests (v2 only — schema_version: 2)
    if ls manifests/*.yaml 1>/dev/null 2>&1; then
        [[ "$JSON_OUTPUT" != "true" ]] && echo ""
        [[ "$JSON_OUTPUT" != "true" ]] && echo "Manifests (v2/defs/manifest.schema.json):"
        for f in manifests/*.yaml; do
            # Only validate v2 manifests (schema_version: 2)
            local_version=$(python3 -c "import yaml; print(yaml.safe_load(open('$f')).get('schema_version', 1))" 2>/dev/null || echo "1")
            if [[ "$local_version" == "2" ]]; then
                validate_file "$f" "v2/defs/manifest.schema.json" || overall_exit=$?
            else
                [[ "$JSON_OUTPUT" != "true" ]] && echo -e "  ${YELLOW}-${NC} $f (v1, skipped)"
            fi
        done
    fi

    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo ""
        echo "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED invalid${NC}, ${RED}$ERRORS errors${NC}"
    fi
fi

if [[ $ERRORS -gt 0 || $overall_exit -eq 2 ]]; then
    exit 2
elif [[ $FAILED -gt 0 || $overall_exit -eq 1 ]]; then
    exit 1
fi
exit 0
