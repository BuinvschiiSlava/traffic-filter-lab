# Security

## Lab assumptions

- The host is a disposable Ubuntu VM.
- A snapshot or console recovery path exists.
- The user reviews `.env` before running scripts.
- `ALLOWED_CIDR` is a private laboratory subnet.
- PostgreSQL is never published to the host.

## Deliberate controls

- application and data networks are marked internal;
- only the edge container publishes a port;
- containers drop Linux capabilities and enable `no-new-privileges`;
- edge and app filesystems are read-only with small tmpfs mounts;
- container logs are size-limited;
- firewall rules live in a dedicated chain and have a dedicated rollback;
- passwords and state files are excluded from Git.

## Not covered

- IPv6 filtering;
- TLS termination;
- production secret management;
- high availability;
- protection from application-layer attacks;
- policies for multiple physical interfaces.

Do not report real credentials, private keys, public IP addresses or production configuration in a GitHub issue.
