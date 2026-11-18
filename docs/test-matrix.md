# Test matrix

| ID | Source | Destination | Expected result | Evidence |
|---|---|---|---|---|
| T01 | Host | edge `/health` | HTTP 200 | curl output |
| T02 | Host | edge `/api/health` | JSON status `ok` | curl output |
| T03 | Allowed client | published edge port | HTTP 200 | curl output and rule counter |
| T04 | Blocked client | published edge port | dropped | curl timeout and kernel log |
| T05 | DMZ test container | edge | allowed | segmentation script |
| T06 | DMZ test container | PostgreSQL | blocked | segmentation script |
| T07 | Data test container | PostgreSQL | ready | `pg_isready` |
| T08 | Host | PostgreSQL 5432 | no published port | Compose inspection |
| T09 | VM reboot | firewall policy | restored when persistence enabled | repeated T03/T04 |
| T10 | Rollback | custom chain | removed | `iptables -S` |

For a portfolio result, save sanitized screenshots of the architecture, Compose status, firewall counters and the two client probes. Do not include real public IP addresses or credentials.
