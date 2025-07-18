#!/bin/bash

REGION="ap-south-1"
CUTOFF_DATE=$(date -u -d '4 weeks ago' +%s)
DRY_RUN=true  # Always true for this script

echo "🔍 DRY RUN MODE ENABLED — No deletions will be performed."
echo
echo "🚀 Starting SAFE Lambda DRY RUN cleanup in region: $REGION"
echo "------------------------------------------------------------"
echo

# Step 0: Show initial usage and limits in GB
echo "📊 Fetching Lambda account usage and limits..."
ACCOUNT_SETTINGS=$(aws lambda get-account-settings --region "$REGION")

LIMIT_BYTES=$(echo "$ACCOUNT_SETTINGS" | jq '.AccountLimit.TotalCodeSize')
USED_BYTES=$(echo "$ACCOUNT_SETTINGS" | jq '.AccountUsage.TotalCodeSize')
FUNCTION_COUNT=$(echo "$ACCOUNT_SETTINGS" | jq '.AccountUsage.FunctionCount')

LIMIT_GB=$(echo "scale=2; $LIMIT_BYTES / (1024*1024*1024)" | bc)
USED_GB=$(echo "scale=2; $USED_BYTES / (1024*1024*1024)" | bc)

printf "\n%-25s %s\n" "Function Count:" "$FUNCTION_COUNT"
printf "%-25s %s GB\n" "Storage Limit:" "$LIMIT_GB"
printf "%-25s %s GB\n\n" "Storage Used:" "$USED_GB"

echo "------------------------------------------------------------"
echo

# Step 1: List all Lambda functions
FUNCTIONS=$(aws lambda list-functions --region "$REGION" --query 'Functions[*].FunctionName' --output text)

for fn in $FUNCTIONS; do
  echo "🔍 Checking function: $fn"

  VERSIONS=$(aws lambda list-versions-by-function \
    --function-name "$fn" --region "$REGION" \
    --query 'Versions[?Version!=`$LATEST`]' --output json)

  ALIASES=$(aws lambda list-aliases \
    --function-name "$fn" --region "$REGION" \
    --query 'Aliases[*].FunctionVersion' --output text)

  for row in $(echo "$VERSIONS" | jq -c '.[]'); do
    VERSION=$(echo "$row" | jq -r '.Version')
    LAST_MODIFIED=$(echo "$row" | jq -r '.LastModified')
    VERSION_TIMESTAMP=$(date -u -d "$LAST_MODIFIED" +%s)

    if echo "$ALIASES" | grep -qw "$VERSION"; then
      echo "   ⛔ Skipping version $VERSION — used by alias."
    elif [ "$VERSION_TIMESTAMP" -lt "$CUTOFF_DATE" ]; then
      echo "   🗑️  DRY RUN: Deletable version $VERSION (created $LAST_MODIFIED)"
      echo "      ⚠️  Would delete version $VERSION"
    else
      echo "   🕒 Skipping version $VERSION — not older than 4 weeks."
    fi
  done

  echo
done

echo "------------------------------------------------------------"
echo "📊 Final (simulated) account usage after DRY RUN cleanup:"
ACCOUNT_SETTINGS=$(aws lambda get-account-settings --region "$REGION")

LIMIT_BYTES=$(echo "$ACCOUNT_SETTINGS" | jq '.AccountLimit.TotalCodeSize')
USED_BYTES=$(echo "$ACCOUNT_SETTINGS" | jq '.AccountUsage.TotalCodeSize')
FUNCTION_COUNT=$(echo "$ACCOUNT_SETTINGS" | jq '.AccountUsage.FunctionCount')

LIMIT_GB=$(echo "scale=2; $LIMIT_BYTES / (1024*1024*1024)" | bc)
USED_GB=$(echo "scale=2; $USED_BYTES / (1024*1024*1024)" | bc)

printf "\n%-25s %s\n" "Function Count:" "$FUNCTION_COUNT"
printf "%-25s %s GB\n" "Storage Limit:" "$LIMIT_GB"
printf "%-25s %s GB\n\n" "Storage Used:" "$USED_GB"
