# Attribution

`mongodb-to-tidb-migration` draws its MongoDB pattern catalogue, the
embed-versus-reference rules, the anti-pattern diagnostics, and the
`$queryStats` snippets from the
[mongodb/agent-skills](https://github.com/mongodb/agent-skills) project,
Apache License 2.0, Copyright MongoDB, Inc., as of upstream commit `8ada610`
(2026-09-02). Source skill: `mongodb-schema-design` and its `references/`
directory; `mongodb-query-optimizer` and `mongodb-connection` were read for
context.

Changes made when vendoring into this repo:

- The upstream material describes how to design *for* MongoDB. This skill
  reads the same patterns in reverse, as the shapes a migration inherits, and
  maps each one to a TiDB counterpart in `references/pattern-map.md`. The
  mapping, the type table, the query translation table, the data-movement and
  cutover references, the plan template, and `scripts/infer-schema.js` are
  new in this repo.
- Upstream thresholds and diagnostics are quoted where they still apply (array
  cardinality guidance, `$indexStats` usage, `$queryStats` shape queries) and
  restated in this repo's voice.
- TiDB-side claims follow the fact check recorded for the sibling
  `tidb-engineer` skill in `docs/research/tidb-engineer-fact-check.md`.
  Thirty-three claims specific to this skill (TiDB import paths, transaction
  limits, JSON and regex functions, hotspot behaviour, MongoDB change streams,
  `$queryStats`, mongosh) were checked against docs.pingcap.com, pingcap/tidb
  source, and mongodb.com/docs on 2026-09-10; verdicts and the six corrections
  they forced are in `docs/research/mongodb-to-tidb-migration-fact-check.md`.
