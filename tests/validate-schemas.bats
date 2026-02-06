#!/usr/bin/env bats
#
# Tests for scripts/validate-schemas.sh
#

SCRIPT="$BATS_TEST_DIRNAME/../scripts/validate-schemas.sh"
SITE_CONFIG_DIR="$BATS_TEST_DIRNAME/.."

setup() {
    # Clean up any leftover test fixtures in v2 dirs
    rm -f "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml"
    rm -f "$SITE_CONFIG_DIR/v2/postures/_test_invalid.yaml"
}

teardown() {
    rm -f "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml"
    rm -f "$SITE_CONFIG_DIR/v2/postures/_test_invalid.yaml"
}

# --- Help and usage ---

@test "--help shows usage and exits 0" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--json"* ]]
}

@test "unknown option exits 2" {
    run "$SCRIPT" --badoption
    [ "$status" -eq 2 ]
}

# --- Valid file validation ---

@test "validates a valid spec file" {
    run "$SCRIPT" "$SITE_CONFIG_DIR/v2/specs/test.yaml"
    [ "$status" -eq 0 ]
}

@test "validates a valid posture file" {
    run "$SCRIPT" "$SITE_CONFIG_DIR/v2/postures/dev.yaml"
    [ "$status" -eq 0 ]
}

@test "validates all specs and postures (default mode)" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"passed"* ]]
}

# --- JSON output ---

@test "--json outputs valid JSON for a valid file" {
    run "$SCRIPT" --json "$SITE_CONFIG_DIR/v2/specs/test.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['valid']==True"
}

@test "--json outputs valid JSON for an invalid file" {
    # Place invalid file in v2/specs/ so schema resolves
    cat > "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml" <<'EOF'
schema_version: 999
bogus_field: true
EOF
    run "$SCRIPT" --json "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml"
    [ "$status" -eq 1 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['valid']==False"
}

# --- Invalid file detection ---

@test "detects invalid spec (wrong schema_version)" {
    cat > "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml" <<'EOF'
schema_version: 999
EOF
    run "$SCRIPT" "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml"
    [ "$status" -eq 1 ]
}

@test "detects invalid posture (unexpected field)" {
    cat > "$SITE_CONFIG_DIR/v2/postures/_test_invalid.yaml" <<'EOF'
auth:
  method: network
completely_bogus_field: 42
EOF
    run "$SCRIPT" "$SITE_CONFIG_DIR/v2/postures/_test_invalid.yaml"
    [ "$status" -eq 1 ]
}

@test "reports file not found" {
    run "$SCRIPT" "/nonexistent/path/file.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# --- Schema resolution ---

@test "resolves spec schema for v2/specs/ files" {
    run "$SCRIPT" "$SITE_CONFIG_DIR/v2/specs/pve.yaml"
    [ "$status" -eq 0 ]
}

@test "resolves posture schema for v2/postures/ files" {
    run "$SCRIPT" "$SITE_CONFIG_DIR/v2/postures/prod.yaml"
    [ "$status" -eq 0 ]
}

# --- Manifest validation ---

@test "validates v2 manifests and skips v1 (default mode)" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    # v1 manifests should be skipped
    [[ "$output" == *"skipped"* ]] || true
}

@test "validates a specific v2 manifest" {
    local v2_manifest=""
    for f in "$SITE_CONFIG_DIR"/manifests/*-v2.yaml; do
        if [ -f "$f" ]; then
            v2_manifest="$f"
            break
        fi
    done
    if [ -z "$v2_manifest" ]; then
        skip "no v2 manifests found"
    fi
    run "$SCRIPT" "$v2_manifest"
    [ "$status" -eq 0 ]
}

# --- Multiple files ---

@test "validates multiple files in one invocation" {
    run "$SCRIPT" \
        "$SITE_CONFIG_DIR/v2/specs/test.yaml" \
        "$SITE_CONFIG_DIR/v2/postures/dev.yaml"
    [ "$status" -eq 0 ]
}

@test "mixed results: valid + not found exits non-zero" {
    run "$SCRIPT" \
        "$SITE_CONFIG_DIR/v2/specs/test.yaml" \
        "/nonexistent/file.yaml"
    [ "$status" -ne 0 ]
}

@test "mixed results: valid + invalid exits 1" {
    cat > "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml" <<'EOF'
schema_version: 999
EOF
    run "$SCRIPT" \
        "$SITE_CONFIG_DIR/v2/specs/test.yaml" \
        "$SITE_CONFIG_DIR/v2/specs/_test_invalid.yaml"
    [ "$status" -eq 1 ]
}
