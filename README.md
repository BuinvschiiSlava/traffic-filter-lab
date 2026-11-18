# Traffic Filter Lab

Small Linux lab for Docker network segmentation and host-level traffic filtering with UFW, iptables and the `DOCKER-USER` chain.

> The interesting part is not that the containers run. It is proving which traffic must not reach them.

## What it demonstrates

- three isolated Docker network zones;
- a single published edge service;
- an internal application reachable only through Nginx;
- PostgreSQL without a host port;
- source-based filtering for a Docker-published port;
- bounded firewall logging and an explicit rollback;
- automated service and segmentation checks.

```text
allowed client
      |
      v
Ubuntu host: UFW + DOCKER-USER
      |
      v
edge Nginx -----> internal app -----> PostgreSQL
    dmz             application          data
```

## Why both UFW and iptables

UFW protects normal host services, but Docker publishes ports through NAT before packets reach the chains commonly managed by UFW. The lab therefore keeps host policy in UFW and places container-specific filtering in `DOCKER-USER`.

Official background:

- [Docker packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
- [Ubuntu firewall documentation](https://documentation.ubuntu.com/security/security-features/network/firewall/)
- [Netfilter documentation](https://www.netfilter.org/documentation/)

## Safety boundary

Use a disposable Ubuntu VM with a snapshot. Do not run the firewall scripts on a production server, VPN gateway or remote host that you cannot recover through a console.

The containers can be validated on Docker Desktop, but the UFW and Netfilter path must be tested on Linux.

## Quick start

```bash
cp .env.example .env
# Replace the example password, ALLOWED_CIDR and EXTERNAL_INTERFACE.

./scripts/preflight.sh
docker compose --env-file .env up -d
./scripts/verify-services.sh
./scripts/verify-segmentation.sh
```

Open `http://127.0.0.1:8080` locally before applying the firewall.

On the Ubuntu VM:

```bash
sudo ENABLE_UFW=yes ./scripts/apply-firewall.sh
sudo ./scripts/show-firewall.sh
```

From one machine inside `ALLOWED_CIDR` and another outside it:

```bash
./scripts/probe-client.sh VM_ADDRESS 8080
```

Rollback:

```bash
sudo ./scripts/rollback-firewall.sh
```

## Expected result

| Check | Expected |
|---|---|
| Allowed client to edge port | HTTP 200 |
| Blocked client to edge port | Timeout or drop |
| DMZ container to edge | Allowed |
| DMZ container to PostgreSQL | Blocked |
| Data test container to PostgreSQL | Allowed |
| PostgreSQL host port | Not published |
| Rollback | `TFL-FILTER` removed |

## Documentation

- [Architecture](docs/architecture.md)
- [Ubuntu VM lab guide](docs/lab-guide.md)
- [How the firewall works](docs/firewall-explained.md)
- [Test matrix](docs/test-matrix.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Security decisions](SECURITY.md)

## Repository scope

This is a learning project, not a universal production firewall. Interface names, trusted networks, IPv6 policy, persistence and remote recovery must be designed for the target environment.
