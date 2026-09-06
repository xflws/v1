#!/usr/bin/env python3
"""
Fetch Yahoo Finance prices for ALL 298 EGX stocks.
Uses batch requests with rate limiting to avoid blocks.
Updates instruments.json.php with live prices.
"""
import json
import os
import time
import urllib.request
import urllib.error

INST_FILE = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted\api\data\live\instruments.json.php"

# Load instruments
with open(INST_FILE, encoding="utf-8") as f:
    content = f.read()
instruments = json.loads(content[content.index("\n")+1:])

print(f"Loaded {len(instruments)} instruments")

# Yahoo Finance URL pattern
def fetch_yahoo(ticker):
    """Fetch price from Yahoo Finance for EGX ticker."""
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}.CA?interval=1d&range=5d"
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
    
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
        
        result = data.get("chart", {}).get("result", [])
        if not result:
            return None
        
        meta = result[0].get("meta", {})
        price = meta.get("regularMarketPrice")
        prev = meta.get("chartPreviousClose", meta.get("previousClose"))
        change_pct = meta.get("regularMarketChangePercent")
        
        if price and price > 0:
            return {
                "price": round(price, 2),
                "prev": round(prev, 2) if prev else round(price, 2),
                "change": round(change_pct, 2) if change_pct else 0.0
            }
    except Exception:
        pass
    
    return None

# Fetch prices for all instruments
updated = 0
failed = 0
today = time.strftime("%Y-%m-%d")

print("\nFetching Yahoo Finance prices...\n")

for i, inst in enumerate(instruments):
    ticker = inst.get("ticker", "")
    if not ticker or len(ticker) < 2:
        continue
    
    # Skip complex tickers (ISINs, etc)
    if "-" in ticker or ticker.startswith("EGS"):
        failed += 1
        continue
    
    # Skip if already updated today
    if inst.get("priceUpdateDate") == today and inst.get("last", 0) > 0:
        updated += 1
        continue
    
    result = fetch_yahoo(ticker)
    if result:
        inst["last"] = result["price"]
        inst["prev"] = result["prev"]
        inst["change"] = result["change"]
        inst["priceUpdateDate"] = today
        updated += 1
        print(f"  [{updated}] {ticker}: {result['price']} EGP ({result['change']:+.2f}%)")
    else:
        failed += 1
        if failed % 20 == 0:
            print(f"  ...{failed} not found on Yahoo...")
    
    # Rate limiting - Yahoo allows ~2000 requests/hour
    time.sleep(0.4)
    
    if (i + 1) % 50 == 0:
        print(f"\n  Progress: {i+1}/{len(instruments)} processed, {updated} updated, {failed} not found\n")

# Save updated instruments
guard = "<?php http_response_code(404); exit; ?>\n"
with open(INST_FILE, "w", encoding="utf-8") as f:
    f.write(guard + json.dumps(instruments, indent=4, ensure_ascii=False))

print(f"\n{'='*60}")
print(f"COMPLETE")
print(f"{'='*60}")
print(f"Total instruments: {len(instruments)}")
print(f"Updated with Yahoo prices: {updated}")
print(f"Not found on Yahoo: {failed}")
print(f"File saved: {INST_FILE}")
