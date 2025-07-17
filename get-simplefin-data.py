#!/usr/bin/env python3
"""
SimpleFIN Account Data Checker
Checks what data SimpleFIN is providing for your accounts, with focus on holdings.
"""

import base64
import requests
import json
from urllib.parse import urlparse
import sys


def decode_simplefin_token(token):
    """Decode the Base64 SimpleFIN token to get access URL."""
    try:
        # Add padding if needed
        missing_padding = len(token) % 4
        if missing_padding:
            token += '=' * (4 - missing_padding)
        
        decoded_url = base64.b64decode(token).decode('utf-8')
        return decoded_url
    except Exception as e:
        print(f"Error decoding token: {e}")
        return None


def claim_access_token(claim_url):
    """Exchange claim URL for access URL."""
    try:
        print(f"Claiming access token...")
        response = requests.post(claim_url)
        response.raise_for_status()
        
        # The response should be the access URL
        access_url = response.text.strip()
        print(f"Access URL obtained successfully")
        return access_url
    except Exception as e:
        print(f"Error claiming access token: {e}")
        return None


def get_account_data(access_url):
    """Fetch account data from SimpleFIN API."""
    try:
        # Parse the URL to extract credentials if present
        parsed_url = urlparse(access_url)
        
        # Build accounts URL - preserve the path from access URL and append /accounts
        base_path = parsed_url.path.rstrip('/')
        accounts_url = f"{parsed_url.scheme}://{parsed_url.netloc}{base_path}/accounts"
        
        print(f"Trying URL: {accounts_url}")
        
        # Use basic auth if credentials are in the URL
        auth = None
        if parsed_url.username and parsed_url.password:
            auth = (parsed_url.username, parsed_url.password)
        
        response = requests.get(accounts_url, auth=auth)
        response.raise_for_status()
        
        return response.json()
    except Exception as e:
        print(f"Error fetching account data: {e}")
        return None


def analyze_account(account, account_num):
    """Analyze and display account information."""
    print(f"\n{'='*60}")
    print(f"ACCOUNT #{account_num}")
    print(f"{'='*60}")
    
    # Basic account info
    print(f"Name: {account.get('name', 'N/A')}")
    print(f"ID: {account.get('id', 'N/A')}")
    print(f"Currency: {account.get('currency', 'N/A')}")
    print(f"Balance: {account.get('balance', 'N/A')}")
    print(f"Available Balance: {account.get('available-balance', 'N/A')}")
    
    # Organization info
    org = account.get('org', {})
    if org:
        print(f"\nOrganization:")
        print(f"  Name: {org.get('name', 'N/A')}")
        print(f"  Domain: {org.get('domain', 'N/A')}")
    
    # Check for holdings (investment data)
    holdings = account.get('holdings', [])
    print(f"\nHOLDINGS: {len(holdings)} found")
    
    if holdings:
        print(f"{'='*40}")
        for i, holding in enumerate(holdings, 1):
            print(f"\nHolding #{i}:")
            print(f"  Symbol: {holding.get('symbol', 'N/A')}")
            print(f"  Description: {holding.get('description', 'N/A')}")
            print(f"  Shares: {holding.get('shares', 'N/A')}")
            print(f"  Market Value: {holding.get('market_value', 'N/A')}")
            print(f"  Cost Basis: {holding.get('cost_basis', 'N/A')}")
            print(f"  Purchase Price: {holding.get('purchase_price', 'N/A')}")
            print(f"  Currency: {holding.get('currency', 'N/A')}")
            print(f"  ID: {holding.get('id', 'N/A')}")
    else:
        print("  No holdings found in this account.")
    
    # Check transactions
    transactions = account.get('transactions', [])
    print(f"\nTRANSACTIONS: {len(transactions)} found")
    
    if transactions:
        print("Recent transactions (showing first 3):")
        for i, txn in enumerate(transactions[:3], 1):
            print(f"  {i}. {txn.get('description', 'N/A')} - {txn.get('amount', 'N/A')}")
    
    return len(holdings) > 0


def main():
    """Main function to run the SimpleFIN checker."""
    print("SimpleFIN Account Data Checker")
    print("=" * 40)
    
    # Get SimpleFIN token from user
    if len(sys.argv) > 1:
        token = sys.argv[1]
    else:
        token = input("Enter your SimpleFIN token or access URL: ").strip()
    
    if not token:
        print("No token provided. Exiting.")
        return
    
    # Check if it's already an access URL (contains @ symbol with credentials)
    if '@' in token and token.startswith('https://'):
        print("Access URL detected directly")
        access_url = token
    else:
        print(f"\nDecoding claim token...")
        claim_url = decode_simplefin_token(token)
        
        if not claim_url:
            print("Failed to decode token.")
            return
        
        print(f"Claim URL decoded: {claim_url}")
        
        # Exchange claim URL for access URL
        access_url = claim_access_token(claim_url)
        
        if not access_url:
            print("Failed to claim access token.")
            return
    
    print(f"Fetching account data...")
    
    # Get account data using access URL
    data = get_account_data(access_url)
    
    if not data:
        print("Failed to fetch account data.")
        return
    
    # Parse and display accounts
    accounts = data.get('accounts', [])
    print(f"\nFound {len(accounts)} account(s)")
    
    holdings_found = False
    
    for i, account in enumerate(accounts, 1):
        has_holdings = analyze_account(account, i)
        if has_holdings:
            holdings_found = True
    
    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    print(f"Total accounts: {len(accounts)}")
    print(f"Holdings data found: {'YES' if holdings_found else 'NO'}")
    
    if not holdings_found:
        print("\nTroubleshooting:")
        print("- Check if your Fidelity account is properly linked in SimpleFIN")
        print("- Some accounts may take time to sync holdings data")
        print("- Verify the account type supports investment holdings")
        print("- Try refreshing your SimpleFIN connection")


if __name__ == "__main__":
    main()
