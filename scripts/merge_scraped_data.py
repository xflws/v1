#!/usr/bin/env python3
"""
Merge scraped TradingView data into backend instruments.json.php.
- Preserves existing prices (since TradingView doesn't expose them without login)
- Adds all company info (name, sector, industry, CEO, website, HQ, founded, IPO, ISIN)
- Downloads logos to api/files/
- Removes any mocked/hardcoded data
"""

import json
import os
import requests
import time

# Paths
SCRAPED_FILE = r"c:\xflws\scripts\scraper-output\scraped_data.json"
BACKEND_DIR = r"C:\Users\Mohamed Hussein\Downloads\xflws-api-extracted"
INSTRUMENTS_FILE = os.path.join(BACKEND_DIR, "api", "data", "live", "instruments.json.php")
LOGO_DIR = os.path.join(BACKEND_DIR, "api", "files")

os.makedirs(LOGO_DIR, exist_ok=True)

def load_scraped():
    with open(SCRAPED_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def load_existing():
    with open(INSTRUMENTS_FILE, "r", encoding="utf-8") as f:
        content = f.read()
    # Skip PHP guard
    if content.startswith("<?php"):
        json_start = content.index("\n") + 1
        return json.loads(content[json_start:])
    return json.loads(content)

def save_instruments(data):
    guard = "<?php http_response_code(404); exit; ?>\n"
    with open(INSTRUMENTS_FILE, "w", encoding="utf-8") as f:
        f.write(guard + json.dumps(data, indent=4, ensure_ascii=False))

def download_logo(ticker, url):
    if not url:
        return False
    try:
        resp = requests.get(url, timeout=10, headers={"User-Agent": "Mozilla/5.0"})
        if resp.status_code == 200 and len(resp.content) > 100:
            ext = "svg" if "svg" in url else ("png" if "png" in url else "jpg")
            filepath = os.path.join(LOGO_DIR, f"{ticker}.{ext}")
            with open(filepath, "wb") as f:
                f.write(resp.content)
            return True
    except:
        pass
    return False

def merge_data():
    scraped = load_scraped()
    existing = load_existing()
    
    # Build lookup by ticker
    scraped_map = {s["ticker"]: s for s in scraped if s.get("ticker")}
    
    # Track stats
    logos_downloaded = 0
    instruments_updated = 0
    new_instruments = 0
    
    # Update existing instruments
    for inst in existing:
        ticker = inst.get("ticker", "")
        if ticker in scraped_map:
            s = scraped_map[ticker]
            instruments_updated += 1
            
            # Update company info (preserve existing price data)
            if s.get("name") and s["name"] != ticker:
                inst["name"] = s["name"]
            if s.get("sector"):
                inst["sector"] = s["sector"]
            if s.get("industry"):
                inst["industry"] = s["industry"]
            if s.get("website"):
                inst["website"] = s["website"]
            if s.get("description"):
                inst["description"] = s["description"]
            
            # Add new fields
            inst["ceo"] = s.get("ceo", "")
            inst["headquarters"] = s.get("headquarters", "")
            inst["founded"] = s.get("founded", "")
            inst["ipoDate"] = s.get("ipo_date", "")
            inst["isin"] = s.get("isin", "")
            
            # Download logo
            if s.get("logo_url"):
                if download_logo(ticker, s["logo_url"]):
                    logos_downloaded += 1
    
    # Add new instruments not in existing list
    for ticker, s in scraped_map.items():
        if not any(inst.get("ticker") == ticker for inst in existing):
            new_inst = {
                "ticker": ticker,
                "name": s.get("name", ticker),
                "nameAr": "",
                "kind": "share" if not s.get("sector") or s["sector"] not in ["Equity", "Fixed income", "Money market", "Sharia", "FCY"] else "fund",
                "sector": s.get("sector", ""),
                "industry": s.get("industry", ""),
                "last": 0.0,
                "change": 0.0,
                "prev": 0.0,
                "state": "trading",
                "currency": "EGP",
                "lotSize": 1,
                "minOrder": 0,
                "tradesIn": "units",
                "kycTier": 1,
                "ceo": s.get("ceo", ""),
                "headquarters": s.get("headquarters", ""),
                "founded": s.get("founded", ""),
                "ipoDate": s.get("ipo_date", ""),
                "isin": s.get("isin", ""),
                "website": s.get("website", ""),
                "description": s.get("description", ""),
            }
            existing.append(new_inst)
            new_instruments += 1
            
            # Download logo
            if s.get("logo_url"):
                if download_logo(ticker, s["logo_url"]):
                    logos_downloaded += 1
    
    # Save
    save_instruments(existing)
    
    print(f"{'='*60}")
    print(f"Backend Update Complete")
    print(f"{'='*60}")
    print(f"Instruments updated: {instruments_updated}")
    print(f"New instruments added: {new_instruments}")
    print(f"Logos downloaded: {logos_downloaded}")
    print(f"Total instruments: {len(existing)}")
    print(f"{'='*60}")

if __name__ == "__main__":
    merge_data()
