# Ubuntu VM lab guide

## 1. Prepare the VM

Recommended minimum:

- Ubuntu Server 24.04 LTS;
- 2 vCPU;
- 4 GB RAM;
- 20 GB disk;
- NAT adapter for package downloads;
- Host-only adapter for test clients.

Create a snapshot before changing firewall rules. Record the VM address, interface names and the address range of the Host-only network.

## 2. Install prerequisites

Install Docker Engine and the Compose plugin using the official Docker instructions. Install `ufw`, `iptables` and `curl` if they are not present.

Make sure the current user can run Docker and that `docker version` reaches the daemon.

## 3. Configure the lab

```bash
cp .env.example .env
```

Change:

- `ALLOWED_CIDR` to the Host-only client subnet;
- `EXTERNAL_INTERFACE` to the VM interface receiving client traffic (`ip -br link`);
- `POSTGRES_PASSWORD` to a new laboratory password;
- `WEB_PORT` only if 8080 is already in use.

Run:

```bash
./scripts/preflight.sh
docker compose --env-file .env up -d
./scripts/verify-services.sh
./scripts/verify-segmentation.sh
```

## 4. Protect the published port

Keep the hypervisor console open. If the VM is accessed over SSH, confirm that the `OpenSSH` UFW profile exists before enabling UFW.

```bash
sudo ENABLE_UFW=yes ./scripts/apply-firewall.sh
sudo ./scripts/show-firewall.sh
```

## 5. Test from two clients

Use one client whose address belongs to `ALLOWED_CIDR` and another client outside it.

Expected:

- allowed client receives `edge: ok`;
- blocked client times out because the packet is dropped;
- rule counters increase;
- blocked probes appear in the kernel journal with prefix `TFL-DROP`.

Examples for inspection:

```bash
sudo journalctl -k -g TFL-DROP
sudo ./scripts/show-firewall.sh
```

## 6. Reboot test

Rules are intentionally not persisted by default. Persistence is an explicit learning step because a broken persistent firewall can prevent recovery.

After the policy is verified, install the distribution persistence mechanism and rerun with `PERSIST_RULES=yes`.

Reboot the VM and repeat the test matrix.

## 7. Roll back

```bash
sudo ./scripts/rollback-firewall.sh
```

Verify that `TFL-FILTER` no longer exists and both clients can reach the published port again.
