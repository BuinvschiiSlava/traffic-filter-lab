# How the firewall works

## Netfilter, iptables and UFW

Netfilter is the packet-processing subsystem in the Linux kernel. `iptables` is a command-line tool for managing rules exposed by Netfilter. UFW is a higher-level Ubuntu interface that creates firewall rules for common host policies.

## Why a normal UFW rule is not enough

When Docker publishes a container port, it creates NAT and forwarding rules. The packet is translated before it reaches the host input path normally controlled by UFW. A service can therefore remain reachable even when a user expects an ordinary UFW deny rule to block it.

Docker provides `DOCKER-USER` as the place for administrator-defined filtering before Docker's own forwarding rules accept the traffic.

## Project chain

The script creates one dedicated chain:

```text
DOCKER-USER
    |
    v
TFL-FILTER
    |
    +-- established or related -> return
    +-- external interface + source in ALLOWED_CIDR + original WEB_PORT -> return
    +-- external interface + other connections to original WEB_PORT -> rate-limited log
    +-- external interface + other connections to original WEB_PORT -> drop
    +-- unrelated traffic -> return
```

`--ctorigdstport` uses connection tracking to match the port requested before Docker's DNAT changed the destination.

## Why RETURN is used

The custom chain owns only this lab's policy. `RETURN` sends unrelated or permitted traffic back to `DOCKER-USER`, allowing Docker and any other administrator rules to continue processing it. This is less intrusive than accepting every permitted packet globally.

Matching `EXTERNAL_INTERFACE` is essential: the project filters traffic arriving from clients without accidentally blocking east-west container traffic inside the lab networks.

## Rollback

The rollback removes the jump from `DOCKER-USER`, flushes the custom chain, deletes it and removes the project UFW rule. It does not reset the complete firewall.
