# TiDB Cloud

Provisioning, tiers, and the cloud-specific limits that change generated code. TiDB Cloud Serverless was renamed TiDB Cloud Starter on 2025-08-12; "TiDB X" is the object-storage architecture that Starter, Essential, and Premium run on, not a plan name. Since 2026-04 the console calls Starter and Essential deployments "instances" and Dedicated deployments "clusters"; treat the words as interchangeable in requests.

## Tiers

| Tier | Shape | Notes that matter to code |
|---|---|---|
| Zero | Free, unauthenticated, disposable; expires in 30 days unless claimed | Sandbox only. Public CA TLS. |
| Starter | Serverless, autoscaling, free quota per organisation | Public CA TLS; HTTP serverless driver available; full-text and auto embedding in supported regions; no `FLASHBACK CLUSTER` |
| Essential | Serverless with reserved capacity | As Starter with higher limits; full-text and auto embedding availability lags Starter |
| Premium | Public preview since 2026-04 on AWS and Alibaba Cloud | TiDB X architecture; no `FLASHBACK CLUSTER` |
| Dedicated | Provisioned nodes, VPC | Downloaded CA for public endpoints; TiFlash sizing is explicit; full feature set |
| Self-managed | TiUP, TiDB Operator | Whatever the operator configured; probe everything |

Starter free quota, at the time of vendoring: 5 GiB row storage, 5 GiB columnar storage, and 50 million Request Units per month for each of the first five Starter clusters in an organisation. When quota or the spending limit is exhausted, new connections are rejected and existing ones throttle until the next month or a limit increase. RUs scale with operation type and the data read, written, and returned, so full scans and wide result sets cost more; treat RU consumption as a cost signal.

## Disposable sandbox: Zero

One unauthenticated call returns a connection string. Useful for trying DDL against a real TiDB before touching a shared cluster.

```bash
curl -s -X POST https://zero.tidbapi.com/v1beta1/instances -H 'Content-Type: application/json' -d '{"tag":"scratch"}'
```

The response carries `instance.connectionString`, `instance.claimInfo.claimUrl`, and `instance.expiresAt`. Connect with TLS. Claim it through the URL before expiry to convert it into a Starter cluster; otherwise it is destroyed and cannot be renewed. Credentials are short-lived and low-sensitivity, so keep them in environment variables rather than shell history.

## Provisioning with the CLI

Install and authenticate before any cluster operation:

```bash
curl https://raw.githubusercontent.com/tidbcloud/tidbcloud-cli/main/install.sh | sh
command -v ticloud
ticloud auth login --insecure-storage     # browser flow
ticloud auth whoami
```

Cluster and branch lifecycle:

```bash
ticloud serverless region                                              # list regions first
ticloud project list                                                   # find the project id
ticloud serverless create --display-name <name> --region <region> --project-id <project-id>
ticloud serverless list -p <project-id> -o json
ticloud serverless describe -c <cluster-id>
ticloud serverless delete -c <cluster-id>                              # confirm with the user first

ticloud serverless branch create --cluster-id <cluster-id> --display-name <branch>
ticloud serverless branch list --cluster-id <cluster-id>
ticloud serverless branch delete --cluster-id <cluster-id> --branch-id <branch-id>

ticloud serverless sql-user create --user <name> --password <pw> --role role_readwrite --cluster-id <cluster-id>
ticloud serverless import start --cluster-id <cluster-id> --local.file-path <file> --file-type CSV --local.target-database <db> --local.target-table <table>
ticloud serverless export create --cluster-id <cluster-id> --target-type LOCAL
```

Ask for the region first, then the project, then the display name. Cluster creation takes up to a minute; run the create once and poll with `list` rather than re-issuing it. Never print a stored password back to the user; the console at `https://tidbcloud.com/clusters/<cluster-id>/overview?orgId=<org-id>&projectId=<project-id>` handles `.env` downloads and SQL users when the CLI cannot.

Branches are copy-on-write clones of a Starter cluster: cheap, isolated, and the right place to test a migration or a destructive DDL.

## Connection details

Console **Connect** dialog gives the host, port 4000, prefixed username, and a `DATABASE_URL`. Passwords contain characters that must be percent-encoded in a URL; copying the console's URL avoids the mistake. TLS rules are in `references/tls-connections.md`.

## Serverless-tier limits to design around

- HTTP driver: 10,000 rows per query, one statement per call, no private endpoints; see `references/serverless-driver.md`.
- AWS public endpoints drop connections idle for 340 s and TCP keepalive cannot prevent it; the docs also recommend a maximum connection lifetime starting at 5 minutes. Keep pool idle timeout at or below 300 s and recycle connections.
- No `FLASHBACK CLUSTER`, no custom TiKV configuration, and TiFlash replicas are provisioned on demand.
- Cold start after inactivity adds latency to the first query; keepalive queries are a trade against RU cost.

## Data import and export

Small files: `ticloud serverless import`. Large loads: the console import from S3, GCS, or Azure Blob (physical import mode on Dedicated), or `IMPORT INTO ... FROM 's3://...'` SQL (GA v7.5.0; Starter and Essential accept S3 and Alibaba OSS sources). Dumps: `ticloud serverless export` or Dumpling. Change capture out of TiDB Cloud: changefeeds (TiCDC) to Kafka, MySQL, or object storage, configured in the console.
