# Lambda Cleanup Utility

This project provides tools to monitor and manage AWS Lambda storage usage, including automated cleanup of old Lambda function versions. It includes:

- **Automated alerting and cleanup trigger script** (`SendAlert.js`)
- **Safe cleanup script** (`lambda-cleanup.sh`)
- **Dry-run cleanup script** (`lambda-cleanup-dryrun.sh`)

## Features
- Monitors AWS Lambda storage usage and sends alerts via SNS when usage exceeds a threshold
- Automatically triggers cleanup of old Lambda versions (older than 4 weeks, not referenced by aliases)
- Supports dry-run mode for safe testing
- Fully configurable via command-line arguments

## Requirements
- Node.js 16+
- AWS CLI installed and configured with appropriate permissions
- `jq` and `bc` installed (for shell scripts)
- AWS credentials with permissions for Lambda and SNS operations

## Setup
1. **Install dependencies:**
   ```sh
   npm install
   ```
2. **Configure AWS CLI:**
   Ensure your AWS CLI is configured with credentials and default region.
   ```sh
   aws configure
   ```

## Usage

### 1. SendAlert.js (Alert & Cleanup Trigger)
This script checks Lambda storage usage and triggers cleanup (or dry run) if usage exceeds 80% or if `--dry-run` is specified. It also sends alerts and reports to an SNS topic.

**Required arguments:**
- `--region <aws-region>`: AWS region (e.g., `ap-south-1`)
- `--sns-topic-arn <sns-topic-arn>`: SNS topic ARN for alerts

**Optional:**
- `--dry-run`: Only simulate cleanup, do not delete anything

**Example:**
```sh
node SendAlert.js --region ap-south-1 --sns-topic-arn arn:aws:sns:ap-south-1:123456789012:lambda-cleanup-alerts
```

**Dry run:**
```sh
node SendAlert.js --region ap-south-1 --sns-topic-arn arn:aws:sns:ap-south-1:123456789012:lambda-cleanup-alerts --dry-run
```

### 2. lambda-cleanup.sh (Actual Cleanup)
Deletes Lambda function versions older than 4 weeks that are not referenced by any alias. Prints before/after usage.

**Usage:**
```sh
bash lambda-cleanup.sh
```

> **Note:** The region is currently hardcoded in the script. Edit the `REGION` variable at the top if needed.

### 3. lambda-cleanup-dryrun.sh (Dry Run)
Simulates the cleanup process, showing what would be deleted without making any changes.

**Usage:**
```sh
bash lambda-cleanup-dryrun.sh
```

> **Note:** The region is currently hardcoded in the script. Edit the `REGION` variable at the top if needed.

## Deployment & Automation

You can run this project from an AWS Lightsail instance, EC2, or any server with Node.js and AWS CLI access. For automation, you can:

- **Schedule with cron:** Set up a cron job on your server to run the alert/cleanup script at regular intervals (e.g., daily or weekly).
- **Use AWS CloudWatch Events (EventBridge):** Trigger the script using CloudWatch scheduled events, either by invoking it directly (with Lambda or SSM) or by integrating with your infrastructure.

This flexibility allows you to automate Lambda cleanup and alerting according to your operational needs.

## NPM Scripts
- `npm start`: Runs `