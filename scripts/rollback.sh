#!/bin/bash

# ============================================================
# Remediation & Rollback Script
# Capstone Project - Incident Response Automation
# ============================================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOGFILE="logs/remediation.log"
MAX_RETRIES=3
RETRY_COUNT=0
TARGET_CONTAINER=${1:-"sample-app"}

mkdir -p logs

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# ---- 1. Check if container is healthy ----
check_health() {
    local container=$1
    local status=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null)
    if [ "$status" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# ---- 2. Circuit breaker ----
circuit_breaker() {
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        log "CIRCUIT BREAKER TRIGGERED: Max retries ($MAX_RETRIES) reached for $TARGET_CONTAINER"
        log "Manual intervention required"
        exit 1
    fi
}

# ---- 3. Restart container with backoff ----
restart_with_backoff() {
    local container=$1
    local wait_time=$((RETRY_COUNT * 5 + 5))

    log "Attempting restart of $container (attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES)"
    log "Waiting ${wait_time}s before restart (exponential backoff)"
    sleep "$wait_time"

    docker restart "$container" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "SUCCESS: $container restarted successfully"
        return 0
    else
        log "FAILED: Could not restart $container"
        return 1
    fi
}

# ---- 4. Verify recovery ----
verify_recovery() {
    local container=$1
    log "Verifying recovery of $container..."
    sleep 3
    if check_health "$container"; then
        log "RECOVERY CONFIRMED: $container is healthy"
        return 0
    else
        log "RECOVERY FAILED: $container is still unhealthy"
        return 1
    fi
}

# ---- Main Remediation Flow ----
log "============================================================"
log "REMEDIATION SCRIPT STARTED"
log "Target container: $TARGET_CONTAINER"
log "============================================================"

# Check initial health
if check_health "$TARGET_CONTAINER"; then
    log "Container $TARGET_CONTAINER is currently healthy - no action needed"
    exit 0
fi

log "Container $TARGET_CONTAINER is UNHEALTHY - starting remediation"

# Remediation loop with circuit breaker
while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
    circuit_breaker
    restart_with_backoff "$TARGET_CONTAINER"

    if verify_recovery "$TARGET_CONTAINER"; then
        log "============================================================"
        log "REMEDIATION SUCCESSFUL after $((RETRY_COUNT + 1)) attempt(s)"
        log "============================================================"
        exit 0
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    log "Retry count: $RETRY_COUNT of $MAX_RETRIES"
done

log "============================================================"
log "REMEDIATION FAILED - Manual intervention required"
log "============================================================"
exit 1