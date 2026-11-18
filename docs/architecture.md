# Architecture

## Traffic path

```text
LAN client
   |
   | TCP WEB_PORT
   v
Linux host
   |
   | UFW protects host services
   | DOCKER-USER -> TFL-FILTER protects published Docker traffic
   v
edge container
   |
   | /api/*
   v
app container
   |
   | isolated data network
   v
PostgreSQL
```

## Network membership

| Service | DMZ | Application | Data | Published port |
|---|:---:|:---:|:---:|:---:|
| edge | yes | yes | no | `WEB_PORT` |
| app | no | yes | yes | none |
| database | no | no | yes | none |
| dmz-test | yes | no | no | none |
| data-test | no | no | yes | none |

The edge cannot reach PostgreSQL directly. The DMZ test container cannot resolve or connect to the database service. Only services attached to the data network can reach PostgreSQL.

## Trust boundaries

1. Host boundary: UFW controls host services such as SSH.
2. Docker publication boundary: `DOCKER-USER` filters traffic forwarded to published container ports.
3. Compose boundary: network membership limits east-west communication.
4. Data boundary: PostgreSQL has no host binding.
