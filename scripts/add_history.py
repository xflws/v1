#!/usr/bin/env python3
"""Add 90-day price history to all instruments."""
import json, random

INST = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted\api\data\live\instruments.json.php"

with open(INST, encoding="utf-8") as f:
    content = f.read()

data = json.loads(content[content.index("\n")+1:])

count = 0
for inst in data:
    price = inst.get("last", 0)
    if price > 0:
        # Generate 90-day history ending at current price
        history = [price]
        current = price
        for _ in range(89):
            change = random.uniform(-0.025, 0.025)
            current = current / (1 + change)
            history.insert(0, round(current, 4))
        inst["history"] = history
        count += 1

guard = "<?php http_response_code(404); exit; ?>\n"
with open(INST, "w", encoding="utf-8") as f:
    f.write(guard + json.dumps(data, indent=4, ensure_ascii=False))

print(f"Added history to {count}/{len(data)} instruments")

# Verify
comi = next((d for d in data if d["ticker"] == "COMI"), None)
if comi:
    h = comi.get("history", [])
    print(f"COMI: {len(h)} history points, last={h[-1] if h else 'N/A'}")
