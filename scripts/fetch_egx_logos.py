#!/usr/bin/env python3
"""
Scrape TradingView for Egyptian stock logos.
Downloads SVG logos from s3-symbol-logo.tradingview.com
by fetching each stock page and extracting the logo URL.
"""

import re
import os
import time
import requests
from urllib.parse import quote

# Output directory
OUTPUT_DIR = "egx-logos"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Egyptian stocks from the TradingView screener
STOCKS = [
    ("COMI", "Commercial International Bank Egypt"),
    ("TMGH", "Talaat Moustafa Group"),
    ("ETEL", "Telecom Egypt"),
    ("SWDY", "Elsewedy Electric"),
    ("CLHO", "Cleopatra Hospital"),
    ("CPME", "Catalyst Partners Middle East"),
    ("CCAP", "Qala For Financial Investments"),
    ("ACGC", "Arab Cotton Ginning"),
    ("AMES", "Alexandria New Medical Center"),
    ("ABUK", "Abou Kir Fertilizers"),
    ("GLD", "Gold"),
    ("AZEQ", "Azimut Equity Fund"),
    ("XFIX", "XFLWS Fixed Income"),
    ("AFMC", "Alexandria Flour Mills"),
    ("GGCC", "Giza General Contracting"),
]

def get_logo_url(ticker):
    """Fetch the TradingView symbol page and extract the logo URL."""
    url = f"https://www.tradingview.com/symbols/EGX-{ticker}/"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    try:
        resp = requests.get(url, headers=headers, timeout=10)
        if resp.status_code != 200:
            return None, f"HTTP {resp.status_code}"
        
        # Look for the logo URL in the page's JavaScript data
        # TradingView embeds logo URLs in meta tags or script data
        patterns = [
            r'"logo_url"\s*:\s*"([^"]+)"',
            r'"logo"\s*:\s*"([^"]+)"',
            r's3-symbol-logo\.tradingview\.com/[^"]+\.svg',
            r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, resp.text)
            if match:
                logo_url = match.group(0) if 's3-symbol-logo' in pattern else match.group(1)
                if 's3-symbol-logo' not in logo_url:
                    continue
                return logo_url, "OK"
        
        # Fallback: try common name patterns
        name_variants = [
            ticker.lower(),
            ticker.replace('-', '').lower(),
        ]
        
        for name in name_variants:
            test_url = f"https://s3-symbol-logo.tradingview.com/{name}.svg"
            test_resp = requests.get(test_url, headers=headers, timeout=5)
            if test_resp.status_code == 200 and len(test_resp.content) > 100:
                return test_url, "found by ticker name"
        
        return None, "No logo found"
        
    except Exception as e:
        return None, str(e)

def download_logo(url, ticker):
    """Download the logo SVG to the output directory."""
    if not url:
        return False
    
    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        resp = requests.get(url, headers=headers, timeout=10)
        if resp.status_code == 200 and len(resp.content) > 100:
            filepath = os.path.join(OUTPUT_DIR, f"{ticker}.svg")
            with open(filepath, "wb") as f:
                f.write(resp.content)
            return True
    except:
        pass
    return False

def main():
    results = []
    
    print(f"Fetching logos for {len(STOCKS)} Egyptian stocks...\n")
    
    for i, (ticker, name) in enumerate(STOCKS):
        print(f"[{i+1}/{len(STOCKS)}] {ticker} - {name}...")
        
        logo_url, status = get_logo_url(ticker)
        
        if logo_url:
            success = download_logo(logo_url, ticker)
            if success:
                print(f"  ✓ Downloaded: {ticker}.svg")
                results.append((ticker, "OK"))
            else:
                print(f"  ✗ Failed to download")
                results.append((ticker, "Download failed"))
        else:
            print(f"  ✗ {status}")
            results.append((ticker, status))
        
        time.sleep(1)  # Be polite to TradingView
    
    # Summary
    print(f"\n{'='*50}")
    print("SUMMARY")
    print(f"{'='*50}")
    ok = sum(1 for _, s in results if s == "OK")
    print(f"Successful: {ok}/{len(STOCKS)}")
    print(f"\nFiles saved to: {os.path.abspath(OUTPUT_DIR)}")
    
    # Generate a mapping file
    with open(os.path.join(OUTPUT_DIR, "logo_mapping.json"), "w") as f:
        import json
        mapping = {ticker: f"{ticker}.svg" for ticker, status in results if status == "OK"}
        json.dump(mapping, f, indent=2)
        print(f"\nLogo mapping saved to: logo_mapping.json")

if __name__ == "__main__":
    main()
