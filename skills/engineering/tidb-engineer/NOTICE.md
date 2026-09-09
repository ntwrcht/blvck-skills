# Attribution

`tidb-engineer` vendors and condenses material from the
[pingcap/agent-rules](https://github.com/pingcap/agent-rules) project
(AgenticStore), Apache License 2.0, Copyright PingCAP.

Source skills folded into this one: `tidb-sql`, `tidb-query-tuning`, `mysql`,
`tidbx`, `tidb-cloud-zero`, `tidbx-javascript-mysql2`, `tidbx-javascript-mysqljs`,
`tidbx-kysely`, `tidbx-prisma`, `tidbx-nextjs`, `tidbx-serverless-driver`, and
`pytidb`, as of upstream commit `ad6ce7a` (2026-08-18).

Changes made when vendoring into this repo:

- Merged twelve upstream skills into one stack skill with a shared workflow,
  `stack-facts.md`, and a project detector, following this repo's
  `<stack>-engineer` shape.
- Rewrote every reference in this repo's voice: tables over prose lists,
  positive phrasing, one concept per heading. Upstream code samples are kept
  where they were correct and trimmed where they duplicated each other.
- Dropped the `optimizer-oncall-experiences-redacted/` and
  `tidb-customer-planner-issues/` corpora, `mount-tidb-cloud-fs`, the DOT
  rendering script, per-driver `validate_connection` scripts, and the pytidb
  demo templates. The tuning references keep the workflow and the high-signal
  rules those corpora supported.
- Added material not present upstream, from TiDB documentation: `AUTO_ID_CACHE 1`,
  TTL table attributes, JSON generated columns and multi-valued indexes,
  isolation levels and transaction size limits, `AS OF TIMESTAMP` reads, and the
  `BIGINT`-as-string handling for JavaScript drivers. Forty-eight such claims
  were checked against docs.pingcap.com and pingcap/tidb source on 2026-09-09;
  the cited verdicts and the corrections they forced are recorded in
  `docs/research/tidb-engineer-fact-check.md` in this repo.
- Replaced upstream cross-skill paths (`skills/tidb-sql/references/...`) with
  in-folder `references/...` paths, per this repo's portability rule.
- Added `## Artifacts`, `## Next Step`, and `## Reference Map` sections and the
  `## When Not to Use` boundaries against sibling skills in this repo.
