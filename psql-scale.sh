#!/bin/bash
set -e

DB_SYSTEM_ID=$1
TARGET_COUNT=$2

if [ -z "$DB_SYSTEM_ID" ] || [ -z "$TARGET_COUNT" ]; then
  echo "Usage: ./psql-scale.sh <db-system-id> <target-count>"
  exit 1
fi

# ----------------------------------------
# Poll until DB is ACTIVE
# ----------------------------------------
wait_for_active() {
  local MAX_ATTEMPTS=40
  local ATTEMPT=0
  local SLEEP=30

  echo "Waiting for DB to become ACTIVE..."

  while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    STATUS=$(oci psql db-system get \
      --db-system-id "$DB_SYSTEM_ID" \
      --output json \
      | jq -r '.data."lifecycle-state"')

    echo "  State: $STATUS (attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS)"

    if [ "$STATUS" == "ACTIVE" ]; then
      echo "  DB is ACTIVE."
      return 0
    fi

    ATTEMPT=$((ATTEMPT + 1))
    sleep $SLEEP
  done

  echo "Timeout: DB did not reach ACTIVE state in time."
  exit 1
}

# ----------------------------------------
# Get current instance count
# ----------------------------------------
CURRENT_COUNT=$(oci psql db-system get \
  --db-system-id "$DB_SYSTEM_ID" \
  --output json \
  | jq -r '.data."instance-count"')

echo "Current: $CURRENT_COUNT → Target: $TARGET_COUNT"

if [ "$CURRENT_COUNT" == "$TARGET_COUNT" ]; then
  echo "Already at target count. Skipping."
  exit 0
fi

if [ "$TARGET_COUNT" -gt "$CURRENT_COUNT" ]; then
  ACTION="up"
  DIFF=$((TARGET_COUNT - CURRENT_COUNT))
else
  ACTION="down"
  DIFF=$((CURRENT_COUNT - TARGET_COUNT))
fi

echo "Action: $ACTION | Steps: $DIFF"

# ----------------------------------------
# Scale UP
# ----------------------------------------
if [ "$ACTION" == "up" ]; then
  for i in $(seq 1 $DIFF); do
    NODE_NUM=$((CURRENT_COUNT + i))
    echo "Inserting node-$NODE_NUM..."

    oci psql db-system patch \
      --db-system-id "$DB_SYSTEM_ID" \
      --items "[{\"operation\": \"INSERT\", \"selection\": \"instances\", \"value\": {\"displayName\": \"replica-node-$NODE_NUM\"}}]"

    wait_for_active
    echo "Node-$NODE_NUM inserted successfully."
  done

# ----------------------------------------
# Scale DOWN
# - Filter ACTIVE only (exclude DELETED ghost records)
# - Sort by time-created ascending
# - First = primary (oldest), skip it
# - Remove most recently added replica by ID (not display-name)
# ----------------------------------------
elif [ "$ACTION" == "down" ]; then
  for i in $(seq 1 $DIFF); do
    echo "Fetching active instances sorted by age..."

    # Get ACTIVE instances sorted by time-created ascending
    # Output: time-created<TAB>id<TAB>display-name
    ACTIVE_INSTANCES=$(oci psql db-system get \
      --db-system-id "$DB_SYSTEM_ID" \
      --output json \
      | jq -r '
          .data.instances[]
          | select(."lifecycle-state" == "ACTIVE")
          | [."time-created", .id, ."display-name"]
          | @tsv
        ' | sort)

    echo "Active instances (oldest → newest):"
    echo "$ACTIVE_INSTANCES"

    ACTIVE_COUNT=$(echo "$ACTIVE_INSTANCES" | grep -c .)

    if [ "$ACTIVE_COUNT" -le 1 ]; then
      echo "Error: Only one active instance remaining (primary). Cannot scale down further."
      exit 1
    fi

    # Pick the most recently created instance (last line = newest replica)
    TARGET_LINE=$(echo "$ACTIVE_INSTANCES" | tail -n 1)
    TARGET_ID=$(echo "$TARGET_LINE"   | awk -F'\t' '{print $2}')
    TARGET_NAME=$(echo "$TARGET_LINE" | awk -F'\t' '{print $3}')

    # First line = primary (oldest), protect it
    PRIMARY_LINE=$(echo "$ACTIVE_INSTANCES" | head -n 1)
    PRIMARY_ID=$(echo "$PRIMARY_LINE" | awk -F'\t' '{print $2}')

    if [ "$TARGET_ID" == "$PRIMARY_ID" ]; then
      echo "Error: Target instance is the primary. Aborting to protect primary node."
      exit 1
    fi

    echo "Removing replica: $TARGET_NAME (id: $TARGET_ID)..."

    oci psql db-system patch \
      --db-system-id "$DB_SYSTEM_ID" \
      --items "[{\"operation\": \"REMOVE\", \"selection\": \"instances[?id=='$TARGET_ID']\"}]"

    wait_for_active
    echo "Replica $TARGET_NAME removed successfully."
  done
fi

echo "================================================"
echo "Scaling complete. Instance count is now $TARGET_COUNT"
echo "================================================"