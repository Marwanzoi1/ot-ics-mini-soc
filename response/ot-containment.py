#!/usr/bin/python3

import sys
import json
import ipaddress
import subprocess
from datetime import datetime

LOG_FILE = "/var/ossec/logs/ot-containment.log"

EXPECTED_RULE = "100101"

ATTACKER_NETWORK = ipaddress.ip_network("10.10.50.0/24")
OT_NETWORK = "10.10.40.0/24"

PROTECTED_IPS = {
    "10.10.30.20",  # ENG-WS01
    "10.10.40.30",  # OT-HIST01
    "10.10.40.41",  # OT-PLC01
}

PFSENSE_HOST = "admin@10.10.20.1"
PFSENSE_TABLE = "WAZUH_BLOCKLIST"

SSH_KEY = "/var/ossec/active-response/keys/pfsense-containment"


def log(message):
    timestamp = datetime.now().astimezone().isoformat()
    with open(LOG_FILE, "a") as f:
        f.write(f"{timestamp} {message}\n")


def run_pfsense(command):
    result = subprocess.run(
        [
            "/usr/bin/ssh",
            "-i", SSH_KEY,
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "ConnectTimeout=5",
            PFSENSE_HOST,
            command,
        ],
        capture_output=True,
        text=True,
        timeout=15,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"pfSense command failed rc={result.returncode} "
            f"stderr={result.stderr.strip()}"
        )

    return result.stdout.strip()


def extract_alert(message):
    alert = message.get("parameters", {}).get("alert", {})

    rule_id = str(alert.get("rule", {}).get("id", ""))

    data = alert.get("data", {})
    connection = data.get("id", {})

    source_ip = connection.get("orig_h")
    target_ip = connection.get("resp_h")

    return rule_id, source_ip, target_ip


def validate_source(rule_id, source_ip):
    if rule_id != EXPECTED_RULE:
        log(f"IGNORED unexpected_rule={rule_id}")
        return False

    if not source_ip:
        log(f"ERROR rule={rule_id} missing_source_ip")
        return False

    try:
        ip_obj = ipaddress.ip_address(source_ip)
    except ValueError:
        log(f"ERROR invalid_source_ip={source_ip}")
        return False

    if source_ip in PROTECTED_IPS:
        log(f"PROTECTED source={source_ip} action=NONE")
        return False

    if ip_obj not in ATTACKER_NETWORK:
        log(
            f"OUT_OF_SCOPE source={source_ip} "
            f"allowed_network={ATTACKER_NETWORK} action=NONE"
        )
        return False

    return True


def wazuh_check_keys(source_ip):
    control = {
        "version": 1,
        "origin": {
            "name": "ot-containment.py",
            "module": "active-response",
        },
        "command": "check_keys",
        "parameters": {
            "keys": [source_ip]
        },
    }

    print(json.dumps(control), flush=True)

    response_raw = sys.stdin.readline()

    if not response_raw:
        log(f"ERROR source={source_ip} no_check_keys_response")
        return False

    response = json.loads(response_raw)
    action = response.get("command")

    if action == "continue":
        return True

    if action == "abort":
        log(f"DUPLICATE source={source_ip} action=ABORT")
        return False

    log(
        f"ERROR source={source_ip} "
        f"unexpected_check_keys_response={action}"
    )
    return False


def main():
    try:
        raw = sys.stdin.readline()

        if not raw:
            log("ERROR empty_input")
            return

        message = json.loads(raw)

        command = message.get("command")

        if command not in {"add", "delete"}:
            log(f"ERROR invalid_command={command}")
            return

        rule_id, source_ip, target_ip = extract_alert(message)

        if not validate_source(rule_id, source_ip):
            return

        if command == "add":

            if not wazuh_check_keys(source_ip):
                return

            remote_command = (
                f"pfctl -t {PFSENSE_TABLE} -T add {source_ip} "
                f"&& pfctl -k {source_ip} -k {OT_NETWORK}"
            )

            output = run_pfsense(remote_command)

            log(
                f"BLOCK rule={rule_id} "
                f"source={source_ip} "
                f"target={target_ip} "
                f"scope={OT_NETWORK} "
                f"result=SUCCESS output={output!r}"
            )

        elif command == "delete":

            remote_command = (
                f"pfctl -t {PFSENSE_TABLE} -T delete {source_ip}"
            )

            output = run_pfsense(remote_command)

            log(
                f"UNBLOCK rule={rule_id} "
                f"source={source_ip} "
                f"target={target_ip} "
                f"result=SUCCESS output={output!r}"
            )

    except Exception as e:
        try:
            log(f"ERROR exception={repr(e)}")
        except Exception:
            pass


if __name__ == "__main__":
    main()
