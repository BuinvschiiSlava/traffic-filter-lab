# Troubleshooting

## Docker daemon is unavailable

Run `docker version`. If only client information is shown, start Docker Engine and retry.

## DOCKER-USER does not exist

The Docker daemon must be running with its normal firewall integration. Do not set Docker's `iptables` option to false for this lab.

## Allowed client is blocked

Check:

1. the client's actual source address;
2. `ALLOWED_CIDR` in `.env`;
3. `EXTERNAL_INTERFACE` in `.env` (`ip -br link` and `ip route`);
4. the published `WEB_PORT`;
5. `sudo ./scripts/show-firewall.sh`;
6. whether another firewall rule runs before the project jump.

## Blocked client still connects

Check:

1. the client is genuinely outside `ALLOWED_CIDR`;
2. the project jump is the first relevant `DOCKER-USER` rule;
3. the probe targets the Docker host rather than localhost on the client;
4. the original destination port matches `WEB_PORT`;
5. Docker is using the iptables backend expected by the lab.

## The VM became unreachable

Use the hypervisor console, not another network connection. Run the rollback script. If needed, restore the snapshot. Do not experiment with firewall rules on a VM without console recovery.
