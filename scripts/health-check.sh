#!/bin/bash

# Health Check Script for Docker Containers
# Checks container health, resource usage, and recent error logs

set -euo pipefail

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/health-check-$(date +%Y%m%d_%H%M%S).log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Container Health Check Report"
echo "Timestamp: $TIMESTAMP"
echo "========================================"
echo ""

# 1. Check all running container health statuses
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking Container Health Statuses..."
echo "----------------------------------------"

if command -v docker &> /dev/null; then
    if docker ps -q &> /dev/null; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}" | {
            while IFS=$'\t' read -r name status state; do
                if [ "$name" != "NAMES" ]; then
                    if [[ "$state" == "exited" ]] || [[ "$status" == *"Exited"* ]]; then
                        echo -e "${RED}✗ $name - Status: $status - State: ${state:-N/A}${NC}"
                    else
                        echo -e "${GREEN}✓ $name - Status: $status - State: ${state:-N/A}${NC}"
                    fi
                fi
            done
        }
    else
        echo "No containers are currently running"
    fi
else
    echo "Docker is not installed or not accessible"
fi

echo ""

# 2. Check CPU and memory usage
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking CPU and Memory Usage..."
echo "----------------------------------------"

if command -v docker &> /dev/null; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | {
        while IFS=$'\t' read -r container cpu mem; do
            if [ "$container" != "NAME" ]; then
                echo "$container | CPU: $cpu | Memory: $mem"
            fi
        done
    } || echo "Unable to retrieve container stats"
else
    echo "Docker is not available"
fi

echo ""

# 3. Check recent error logs from containers
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking Recent Container Logs for Errors..."
echo "----------------------------------------"

if command -v docker &> /dev/null; then
    docker ps -q | while read -r container_id; do
        container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
        error_count=$(docker logs "$container_id" --tail 20 2>&1 | grep -i "error\|critical" | grep -v "info\|flag\|evaluation" | wc -l)
        
        if [ "$error_count" -gt 0 ]; then
            echo -e "${YELLOW}⚠ $container_name - Found $error_count error(s) in recent logs${NC}"
            docker logs "$container_id" --tail 20 2>&1 | grep -i "error\|critical" | grep -v "info\|flag\|evaluation" | head -5 | sed 's/^/  /'
        else
            echo -e "${GREEN}✓ $container_name - No errors found${NC}"
        fi
    done
else
    echo "Docker is not available"
fi

echo ""

# 4. Output full diagnostic summary with timestamps
echo "========================================"
echo "Diagnostic Summary"
echo "Generated: $TIMESTAMP"
echo "========================================"

total_containers=$(docker ps -a -q 2>/dev/null | wc -l || echo "0")
running_containers=$(docker ps -q 2>/dev/null | wc -l || echo "0")
stopped_containers=$((total_containers - running_containers))

echo "Total Containers: $total_containers"
echo "Running: $running_containers"
echo "Stopped: $stopped_containers"
echo ""

# System resource overview
echo "System Resource Overview:"
if command -v free &> /dev/null; then
    free_output=$(free -h | grep "^Mem:")
    echo "Memory: $free_output"
fi

if command -v uptime &> /dev/null; then
    echo "Uptime: $(uptime | awk -F'up' '{print $2}')"
fi

echo ""
echo "Health Check completed at $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
