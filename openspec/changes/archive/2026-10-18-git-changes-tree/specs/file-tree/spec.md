## ADDED Requirements

### Requirement: Shared porcelain status records
`gleb.file_tree.model.parse_status_records(z)` SHALL parse every porcelain-v2 NUL record once into ordered `{ kind, xy, sub, path, orig }` values. A `2` record SHALL consume its following original-path field. `parse_status(z, prefix)` and the ignored-path set SHALL remain wrappers over those records, and the Changes panel SHALL consume only those records.

#### Scenario: Shared parser preserves rename and copy origins
- **WHEN** `parse_status_records` receives NUL-delimited `2` records for a rename and a copy
- **THEN** each result has kind `2`, its XY and submodule fields, the destination in `path`, and the following NUL field in `orig`

#### Scenario: Shared parser classifies added and unmerged records
- **WHEN** `parse_status` receives an ordinary `.A` record and a `u` record
- **THEN** the ordinary path is `added`, the unmerged path is `conflict`, and neither record is ignored

#### Scenario: Shared parser keeps ignored records separate
- **WHEN** `parse_status` receives a modified tracked record, an untracked record and an ignored record
- **THEN** the status map contains the modified and untracked paths while the ignored set alone contains the ignored path
