#!/usr/bin/env python3
"""Fetch Yahoo Finance prices for ALL 298 EGX stocks and update the server."""
import json
import requests
import time

# Load current instruments from server
INST_URL = "https://xerp.xflws.com/api/index.php?r=market.instruments"
# We can't auth here, so load local file instead
LOCAL_INST = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted\api\data\live\instruments.json.php"

with open(LOCAL_INST, encoding="utf-8") as f:
    content = f.read()
instruments = json.loads(content[content.index("\n")+1:])

print(f"Loaded {len(instruments)} instruments")
print("Fetching Yahoo Finance prices for all stocks...\n")

updated = 0
for i, inst in enumerate(instruments):
    ticker = inst["ticker"]
    if not ticker or len(ticker) < 2:
        continue
    
    # Skip complex tickers (ISINs, etc)
    if "-" in ticker or ticker.startswith("EGS"):
        continue
    
    yahooTicker = ticker + ".CA"
    try:
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{yahooTicker}?interval=1d&range=1d"
        resp = requests.get(url, headers={"User-Agent": "Mozilla/5.0"}, timeout=8)
        if resp.status_code == 200:
            data = resp.json()
            meta = data.get("chart", {}).get("result", [{}])[0].get("meta", {})
            price = meta.get("regularMarketPrice", 0)
            prev = meta.get("chartPreviousClose", meta.get("previousClose", 0))
            change = meta.get("regularMarketChangePercent", 0)
            if price > 0:
                inst["last"] = round(price, 2)
                inst["prev"] = round(prev, 2)
                inst["change"] = round(change, 2)
                updated += 1
                print(f"  [{updated}] {ticker}: {price} EGP ({change:+.2f}%)")
        time.sleep(0.3)
    except Exception as e:
        pass
    
    if (i+1) % 20 == 0:
        print(f"  ...processed {i+1}/{len(instruments)} stocks, {updated} prices found...")

# Save
guard = "<?php http_response_code(404); exit; ?>\n"
with open(LOCAL_INST, "w", encoding="utf-8") as f:
    f.write(guard + json.dumps(instruments, indent=4, ensure_ascii=False))

print(f"\nDone! Updated {updated}/{len(instruments)} instruments with Yahoo Finance prices")
print(f"File saved. Upload to server with FTP.")
