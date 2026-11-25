# Bounded Automated OT Containment

## Overview

The Mini-SOC includes a bounded automated containment mechanism designed to react to validated unauthorized Modbus activity without applying unrestricted or permanent network isolation.

The response is implemented with Wazuh active response, a custom Python script, and pfSense enforcement.

The design goal is narrow, temporary, reversible containment.

## Response Flow

```text
Wazuh unauthorized-write detection
        |
        v
Rule 100101
        |
        v
ot-containment.py
        |
        v
Source validation
        |
        v
pfSense WAZUH_BLOCKLIST
        |
        v
Block source from OT network
        |
        v
Timeout
        |
        v
Automatic unblock
```

## Components

The containment workflow uses:

- Wazuh active response
- `response/ot-containment.py`
- SSH-based pfSense control
- pfSense table `WAZUH_BLOCKLIST`
- timeout-based rollback
- explicit response logging

## Trigger

The active-response workflow is associated with Wazuh rule:

`100101`

This rule identifies unauthorized Modbus write activity.

The response is executed on the Wazuh server side.

## Source Validation

Before applying containment, the Python response script validates the candidate source.

The controlled attacker network is:

`10.10.50.0/24`

The OT network is:

`10.10.40.0/24`

Protected systems include:

- `10.10.30.20` — ENG-WS01
- `10.10.40.30` — OT-HIST01
- `10.10.40.41` — OT-PLC01

This prevents important OT and engineering systems from being accidentally treated as attacker sources.

## pfSense Enforcement

The response uses the pfSense table:

`WAZUH_BLOCKLIST`

The firewall policy restricts members of this table from reaching:

`10.10.40.0/24`

The functional blocking operation is equivalent to:

```text
pfctl -t WAZUH_BLOCKLIST -T add <source>
pfctl -k <source> -k 10.10.40.0/24
```

The first command adds the source to the block table.

The second command terminates existing states between the blocked source and the OT network so that already-established sessions are also interrupted.

## Automatic Removal

When the response timeout expires, the source is removed from the pfSense table.

The functional removal operation is equivalent to:

```text
pfctl -t WAZUH_BLOCKLIST -T delete <source>
```

This makes the action reversible.

## A10 Validation

The A10 test scenario validated the complete containment workflow against ATTACKER01:

`10.10.50.10`

Target asset:

`10.10.40.41`

Containment scope:

`10.10.40.0/24`

Two complete response cycles were preserved.

### First Cycle

```text
2026-08-30T23:43:53
BLOCK
source=10.10.50.10
target=10.10.40.41
result=SUCCESS
```

```text
2026-08-30T23:44:54
UNBLOCK
source=10.10.50.10
target=10.10.40.41
result=SUCCESS
```

### Second Cycle

```text
2026-08-30T23:47:13
BLOCK
source=10.10.50.10
target=10.10.40.41
result=SUCCESS
```

```text
2026-08-30T23:48:14
UNBLOCK
source=10.10.50.10
target=10.10.40.41
result=SUCCESS
```

Each captured containment interval lasted approximately 61 seconds.

Representative evidence:

`test-data/response/a10-containment.log`

## Reversibility

The A10 evidence demonstrates both directions of the response lifecycle:

```text
DETECTION
   |
   v
BLOCK
   |
   v
Temporary containment
   |
   v
UNBLOCK
```

This is important because a successful block alone would not prove that the response was safely reversible.

The preserved logs demonstrate both successful blocking and successful automatic removal.

## Post-Validation Configuration

After successful A10 validation, automated active response was intentionally disabled to prevent unintended lab disruption during later work.

The current configuration contains:

```text
<disabled>yes</disabled>
```

This does not mean A10 failed.

The disabled state reflects the final post-validation safety configuration.

The successful historical execution is preserved independently in:

`test-data/response/a10-containment.log`

The current configuration is preserved in:

`response/wazuh-active-response-config-current-disabled.txt`

## Safety Properties

The containment implementation includes several safeguards:

- attacker-network validation
- protected-IP exclusions
- narrow OT destination scope
- explicit command logging
- automatic timeout
- reversible unblock
- connection-state termination
- server-side execution
- post-validation disablement

These controls reduce the risk of turning an automated defensive action into an uncontrolled availability problem.

## Design Limitation

The implementation is a laboratory proof of concept.

Production OT containment would require additional controls such as:

- formal change-management approval
- high-availability firewall considerations
- asset ownership validation
- redundant path analysis
- process-safety review
- stronger authentication and secrets management
- operator approval for high-impact actions
- fail-safe rollback procedures

The project therefore demonstrates the technical containment mechanism without claiming that the same configuration should be copied directly into a production industrial environment.

## Key Design Principle

The response is intentionally bounded.

The objective is not:

```text
detect -> permanently isolate
```

The objective is:

```text
detect
   ->
validate
   ->
temporarily contain
   ->
automatically restore
   ->
preserve evidence
```

This makes the response more appropriate for an OT laboratory where availability and operational continuity remain important.
