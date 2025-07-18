#!/bin/bash

REGION="ap-south-1"
CUTOFF_DATE=$(date -u -d '4 weeks ago' +%s)

echo "🚀 Starting SAFE Lambda cleanup in region: $REGION"
echo "-----------------------------------------------"
echo

# Step 0: Show initial usage and limits
echo "📊 Fetching Lambda account usage and limits..."
aws lambda get-account-settings --region $REGION \
  --query '{StorageLimit_MB:AccountLimit.TotalCodeSize, StorageUsed_MB:AccountUsage.TotalCodeSize, FunctionCount:AccountUsage.FunctionCount}' \
  --output table

echo
echo "-----------------------------------------------"
echo

# Step 1: List all Lambda functions
FUNCTIONS=$(aws lambda list-functions --region $REGION --query 'Functions[*].FunctionName' --output text)

for fn in $FUNCTIONS; do
  echo "🔍 Checking function: $fn"

  # Step 2: Get all versions except $LATEST
  VERSIONS=$(aws lambda list-versions-by-function \
    --function-name "$fn" --region $REGION \
    --query 'Versions[?Version!="$LATEST"]' --output json)

  ALIASES=$(aws lambda list-aliases \
    --function-name "$fn" --region $REGION \
    --query 'Aliases[*].FunctionVersion' --output text)

  for row in $(echo "$VERSIONS" | jq -c '.[]'); do
    VERSION=$(echo $row | jq -r '.Version')
    LAST_MODIFIED=$(echo $row | jq -r '.LastModified')
    VERSION_TIMESTAMP=$(date -u -d "$LAST_MODIFIED" +%s)

    if echo "$ALIASES" | grep -qw "$VERSION"; then
      echo "   ⛔ Skipping version $VERSION — used by alias."
    elif [ "$VERSION_TIMESTAMP" -lt "$CUTOFF_DATE" ]; then
      echo "   🗑️  Deleting version $VERSION (created $LAST_MODIFIED)"
      aws lambda delete-function --function-name "$fn" --qualifier "$VERSION" --region $REGION
    else
      echo "   🕒 Skipping version $VERSION — not older than 4 weeks."
    fi
  done

  echo
done

echo "-----------------------------------------------"
echo "📊 Final account usage after cleanup:"
aws lambda get-account-settings --region $REGION \
  --query '{StorageLimit_MB:AccountLimit.TotalCodeSize, StorageUsed_MB:AccountUsage.TotalCodeSize, FunctionCount:AccountUsage.FunctionCount}' \
  --output table

echo
echo "✅ Cleanup complete. Your Lambda storage should now be reduced."


