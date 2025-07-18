const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");
const { LambdaClient, GetAccountSettingsCommand } = require("@aws-sdk/client-lambda");
const { exec } = require("child_process");

// Parse command-line arguments for region and SNS topic ARN
const args = process.argv.slice(2);
function getArgValue(flag) {
  const index = args.indexOf(flag);
  if (index !== -1 && args[index + 1]) {
    return args[index + 1];
  }
  return null;
}

const REGION = getArgValue('--region');
const SNS_TOPIC_ARN = getArgValue('--sns-topic-arn');

if (!REGION || !SNS_TOPIC_ARN) {
  console.error('Error: --region and --sns-topic-arn are required arguments.');
  process.exit(1);
}

const lambda = new LambdaClient({ region: REGION });
const sns = new SNSClient({ region: REGION });

const isDryRun = process.argv.includes('--dry-run');
const cleanupCommand = isDryRun
  ? 'bash lambda-cleanup-dryrun.sh --dry-run'
  : 'bash lambda-cleanup.sh';

async function main() {
    const data = await lambda.send(new GetAccountSettingsCommand({}));
    const limit = Number(data.AccountLimit.TotalCodeSize);
    const used = Number(data.AccountUsage.TotalCodeSize);
    const percentUsed = (used / limit) * 100;

    console.log(`Lambda Storage: ${Math.round(used / 1024 / 1024)}MB of ${Math.round(limit / 1024 / 1024)}MB used`);
    console.log(`Usage: ${percentUsed.toFixed(2)}%`);

    if (percentUsed > 80 || isDryRun) {
        console.log(`Storage usage ${isDryRun ? 'dry run requested' : 'critical'}. Triggering ${isDryRun ? 'dry run' : 'cleanup'}...`);

        const alertMessage = `
        🚨 Lambda Storage Alert:
Used: ${(used / 1024 / 1024).toFixed(2)} MB / ${(limit / 1024 / 1024).toFixed(2)} MB
Usage: ${percentUsed.toFixed(2)}%
Triggering ${isDryRun ? 'dry run' : 'automatic cleanup'}.
        `;
        await sns.send(new PublishCommand({
            TopicArn: SNS_TOPIC_ARN,
            Subject: isDryRun ? "Lambda storage DRY RUN alert" : "Lambda storage alert + Cleanup",
            Message: alertMessage,
        }));

        exec(cleanupCommand, (error, stdout, stderr) => {
            if (error) {
                console.error('Cleanup script error:', error);
                return;
            }

            const cleanupReport = `Lambda ${isDryRun ? 'Dry Run' : 'Cleanup'} Completed
Output:
${stdout || stderr}
            `;
            sns.send(new PublishCommand({
                TopicArn: SNS_TOPIC_ARN,
                Subject: isDryRun ? "Lambda Dry Run Report" : "Lambda Cleanup Report",
                Message: cleanupReport,
            })).then(res => console.log("Report sent:", res.MessageId));
        });
    } else {
        console.log("Lambda storage usage is within acceptable limits. No action needed.");
    }
}

main().catch(console.error);
