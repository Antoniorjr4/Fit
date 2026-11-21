"""FitLambda BLE discovery and read-only GATT inspection."""
import argparse
import asyncio
import json
from datetime import datetime, timezone
from pathlib import Path
from bleak import BleakScanner, BleakClient


def stamp():
    return datetime.now(timezone.utc).isoformat()


async def scan(seconds):
    print(f"Scanning for {seconds}s ...")
    devices = await BleakScanner.discover(timeout=seconds, return_adv=True)
    rows = []
    for address, (device, adv) in devices.items():
        row = {"address": address, "name": device.name or adv.local_name,
               "rssi": adv.rssi, "service_uuids": adv.service_uuids,
               "manufacturer_ids": list(adv.manufacturer_data.keys())}
        rows.append(row)
        print(f"{row['address']}  RSSI={row['rssi']}  {row['name']}  services={row['service_uuids']}")
    return rows


async def inspect(address):
    print(f"Connecting to {address} (read-only inspection)...")
    async with BleakClient(address, timeout=25.0) as client:
        print("Connected:", client.is_connected)
        services = []
        for service in client.services:
            characteristics = []
            for char in service.characteristics:
                characteristics.append({"uuid": char.uuid, "properties": list(char.properties),
                                        "descriptors": [d.uuid for d in char.descriptors]})
            services.append({"uuid": service.uuid, "characteristics": characteristics})
            print("SERVICE", service.uuid)
            for c in characteristics:
                print("  CHAR", c["uuid"], c["properties"])
        return services


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scan", type=int, metavar="SECONDS")
    parser.add_argument("--inspect", metavar="ADDRESS_OR_DEVICE_ID")
    parser.add_argument("--output", default="ble_results.json")
    args = parser.parse_args()
    if not args.scan and not args.inspect:
        parser.error("Specify --scan SECONDS or --inspect ADDRESS")
    result = {"timestamp_utc": stamp(), "scan": None, "services": None}
    try:
        if args.scan:
            result["scan"] = await scan(args.scan)
        if args.inspect:
            result["services"] = await inspect(args.inspect)
    finally:
        Path(args.output).write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print("Saved:", args.output)


if __name__ == "__main__":
    asyncio.run(main())
