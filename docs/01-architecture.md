# Architecture and Trust Boundaries

## Design objective

The lab separates industrial control, engineering, monitoring, administration, deception and offensive validation. The design follows three principles:

1. **Defense in depth** - a source can be filtered by pfSense, observed by Zeek, correlated by Wazuh, enriched with asset/process context and, when justified, contained.
2. **Least privilege** - rules are expressed as a specific source, destination and service. The bastion may reach the engineering workstation over SSH but may not use Modbus directly against the PLC.
3. **Deny by default, allow by exception** - temporary installation rules are not treated as permanent policy.

## Zones

| Subnet | Zone | Main systems | Purpose |
|---|---|---|---|
| `10.10.10.0/24` | IDMZ | `JUMP-HOST01`, `CONPOT01`, pfSense gateway `10.10.10.1` | Controlled administration and deception |
| `10.10.20.0/24` | SOC / monitoring | `SOC-SIEM01`, `OT-SENSOR01` | Collection, detection, correlation and dashboards |
| `10.10.30.0/24` | Engineering | `ENG-WS01`, pfSense gateway `10.10.30.1` | Authorized HMI and engineering actions |
| `10.10.40.0/24` | OT control | `OT-PLC01`, `OT-HIST01` | PLC runtime, Modbus and process history |
| `10.10.50.0/24` | Validation | `ATTACKER01` | Controlled offensive testing |

## Key conduits

| Source | Destination | Service | Target state | Reason |
|---|---|---:|---|---|
| `ENG-WS01` | `OT-PLC01` | TCP/502 | Allow | Legitimate Modbus control |
| `ENG-WS01` | `OT-PLC01` | TCP/8443 | Allow | OpenPLC administration |
| `ENG-WS01` | `OT-HIST01` | TCP/8086 | Allow | Historian access |
| `ATTACKER01` | `OT-PLC01` | TCP/502 | Deny after hardening | Reduce direct PLC exposure |
| `ATTACKER01` | `ENG-WS01` | Application ports | Deny | Isolate engineering functions |
| `ATTACKER01` | `SOC-SIEM01` | 443, 1514, 1515, 55000 | Deny | Protect the SOC management plane |
| `ATTACKER01` | `CONPOT01` | Conpot services | Allow | Intentional deception |
| `ATTACKER01` | `CONPOT01` | TCP/22 | Deny after hardening | SSH is real management, not deception |
| `JUMP-HOST01` | `ENG-WS01` | TCP/22 | Allow | Controlled administrative conduit |
| `JUMP-HOST01` | `OT-PLC01` | TCP/502 | Deny | Prevent a shortcut to control |
| `JUMP-HOST01` | `SOC-SIEM01` | TCP/1514 | Allow | Wazuh operational telemetry |
| `JUMP-HOST01` | `SOC-SIEM01` | TCP/1515 | Temporary only | Agent enrollment, then close |

## Passive sensor placement

`OT-SENSOR01` uses a bridged monitoring position with network offloading features disabled where they could distort packet capture. Zeek does not enforce policy. This separation is intentional:

- pfSense routes, filters and logs.
- Zeek observes and produces protocol metadata.
- Wazuh decodes, correlates and prioritizes.
- Response logic decides whether a bounded action is justified.

## Bastion design

`JUMP-HOST01` has one permanent IDMZ interface, a regenerated machine identity and distinct SSH keys. It provides one narrow administrative path to `ENG-WS01`. A successful SSH test validated the intended conduit, while a direct attempt from the bastion to `OT-PLC01:502` timed out.

The Wazuh agent on the bastion uses TCP/1514 after enrollment. TCP/1515 is closed once registration is complete.

