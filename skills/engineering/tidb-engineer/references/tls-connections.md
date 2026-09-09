# TLS Connections

TiDB Cloud public endpoints require TLS with server certificate verification and hostname verification. A client that skips either fails at the handshake or, worse, connects without verifying who it is talking to. Self-managed clusters may or may not enforce TLS; ask, or check `SHOW VARIABLES LIKE 'require_secure_transport'`.

## Recognise a TiDB Cloud gateway

Hosts of the shape `gateway01.<region>.prod.aws.tidbcloud.com` (also `alicloud`, `shared`, `dev`, `staging` variants) are TiDB Cloud. Assume the rules below apply. Usernames on TiDB Cloud carry a cluster prefix: `<prefix>.<user>`, not `<user>`.

| Tier | CA | Client setting |
|---|---|---|
| Starter, Essential, Premium | Let's Encrypt CA in the OS trust store; TLS 1.2 or 1.3 | Verify identity; no CA file needed |
| Dedicated (public endpoint) | Downloaded CA | Verify identity and pass the CA file |
| Dedicated (private link, VPC peering) | Optional | Follow the cluster's `require_secure_transport` |

## Client settings

MySQL CLI:

```bash
mysql -h HOST -P 4000 -u 'PREFIX.USER' -p --ssl-mode=VERIFY_IDENTITY
mysql ... --ssl-mode=VERIFY_IDENTITY --ssl-ca=/path/ca.pem     # Dedicated
```

MariaDB CLI: `--ssl-verify-server-cert`.

Node.js `mysql2`:

```js
ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true }                                        // Starter, Essential
ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true, ca: fs.readFileSync(process.env.TIDB_CA_PATH) }  // Dedicated
```

Prisma `DATABASE_URL`: append `?sslaccept=strict`, or `?sslaccept=strict&sslcert=/absolute/path/ca.pem` for Dedicated.

Go `go-sql-driver/mysql`:

```go
mysql.RegisterTLSConfig("tidb", &tls.Config{MinVersion: tls.VersionTLS12, ServerName: "gateway01.ap-southeast-1.prod.aws.tidbcloud.com"})
db, err := sql.Open("mysql", "USER:PASSWORD@tcp(gateway01.ap-southeast-1.prod.aws.tidbcloud.com:4000)/DB?tls=tidb")
```

Python `PyMySQL` / SQLAlchemy: `ssl_verify_cert=True, ssl_verify_identity=True`, or URL params `?ssl_verify_cert=true&ssl_verify_identity=true`. `mysqlclient` uses `ssl_mode=VERIFY_IDENTITY`.

JDBC: `sslMode=VERIFY_IDENTITY` (plus `trustCertificateKeyStoreUrl` for Dedicated).

Rails `mysql2`: `?ssl_mode=verify_identity` on the URL.

Generic DSN: `ssl_verify_cert=true&ssl_verify_identity=true`.

## Pooling against TiDB Cloud

AWS public endpoints drop connections idle for 340 seconds, TCP keepalive does not prevent it, and connections open longer than 30 minutes can be terminated. Keep pool idle timeout at or below 300 seconds (`idleTimeout: 300_000` in `mysql2`), set a maximum connection lifetime around 5 minutes where the pool supports it, and keep pools small in serverless runtimes, often one connection per function instance. Serverless and edge runtimes that cannot hold TCP use the HTTP driver; see `references/serverless-driver.md`.

## Failure signatures

| Error | Cause |
|---|---|
| `ER_NOT_SUPPORTED_AUTH_MODE` or handshake reset before auth | TLS not enabled on the client |
| `self signed certificate in certificate chain` | Dedicated cluster without the CA file, or a corporate proxy |
| `Hostname/IP does not match certificate's altnames` | Connecting by IP, or through a tunnel; connect by the gateway hostname |
| `Access denied for user 'root'` | Missing the cluster prefix on the username |
| `Too many connections` on Starter | Pool sized for a server, running in a serverless fan-out |
