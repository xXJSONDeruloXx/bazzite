#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Bazzite Changelog Proxy

This script fetches Bazzite changelog data from GitHub releases
and serves it as a local proxy that Steam can use to display updates.
"""

import http.server
import socketserver
import urllib.request
import urllib.parse
import json
import os
import time
import re
from pathlib import Path
import sys

# Cache file path
CACHE_DIR = os.path.expanduser("~/.cache/bazzite")
CACHE_FILE = os.path.join(CACHE_DIR, "changelog-cache.json")
CACHE_EXPIRY = 86400  # 24 hours in seconds

# Ensure cache directory exists
Path(CACHE_DIR).mkdir(parents=True, exist_ok=True)

# Convert markdown to BBCode (simplified version)
def md_to_bbcode(text):
    # Headers
    text = re.sub(r'^###\s+(.*?)$', r'[h3]\1[/h3]', text, flags=re.MULTILINE)
    text = re.sub(r'^##\s+(.*?)$', r'[h2]\1[/h2]', text, flags=re.MULTILINE)
    text = re.sub(r'^#\s+(.*?)$', r'[h1]\1[/h1]', text, flags=re.MULTILINE)
    
    # Lists (simple implementation)
    text = re.sub(r'^(\s*)\*\s+(.*?)$', r'[*] \2', text, flags=re.MULTILINE)
    text = re.sub(r'^(\s*)-\s+(.*?)$', r'[*] \2', text, flags=re.MULTILINE)
    
    # Links
    text = re.sub(r'\[(.*?)\]\((.*?)\)', r'[url=\2]\1[/url]', text)
    
    # Bold and italic
    text = re.sub(r'\*\*(.*?)\*\*', r'[b]\1[/b]', text)
    text = re.sub(r'\*(.*?)\*', r'[i]\1[/i]', text)
    
    # Add list tags
    if '[*]' in text:
        text = re.sub(r'(\[\*\])', r'[list]\n\1', text, count=1)
        if not text.endswith('[/list]'):
            text += '\n[/list]'
    
    return text

def fetch_github_releases():
    """Fetch Bazzite releases from GitHub API"""
    try:
        headers = {
            'User-Agent': 'Bazzite-Changelog-Fetcher',
            'Accept': 'application/vnd.github.v3+json'
        }
        request = urllib.request.Request(
            'https://api.github.com/repos/ublue-os/bazzite/releases?page=1&per_page=5',
            headers=headers
        )
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        print(f"Error fetching releases: {e}", file=sys.stderr)
        return []

def format_releases(releases):
    """Format GitHub releases into Steam BBCode format"""
    bbcode = ''
    
    for release in releases:
        # Skip drafts and prereleases
        if release.get('draft') or release.get('prerelease'):
            continue
        
        # Format the date
        date_str = release.get('published_at', '')
        try:
            # Parse the ISO 8601 date into a cleaner format
            from datetime import datetime
            date_obj = datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%SZ')
            date_str = date_obj.strftime('%Y-%m-%d')
        except:
            date_str = date_str.split('T')[0]
        
        # Add the title
        bbcode += f"[h1]{release.get('name', 'Bazzite Update')} ({date_str})[/h1]\n"
        
        # Convert body from markdown to BBCode
        body = md_to_bbcode(release.get('body', ''))
        bbcode += body + '\n\n[hr]\n\n'
    
    return bbcode

def get_bazzite_changelog():
    """Get Bazzite changelog, using cache if fresh"""
    # Check if we have a recent cache
    if os.path.exists(CACHE_FILE):
        stat_info = os.stat(CACHE_FILE)
        now = time.time()
        if now - stat_info.st_mtime < CACHE_EXPIRY:
            # Cache is fresh, use it
            print("Using cached changelog")
            with open(CACHE_FILE, 'r') as f:
                return json.loads(f.read())
    
    print("Fetching fresh changelog from GitHub API")
    releases = fetch_github_releases()
    bbcode = format_releases(releases)
    
    # Format for Steam
    changelog = {
        "success": 1,
        "latest_current": {
            "buildid": str(int(time.time())),
            "version": "Bazzite Changelog",
            "languages": ["english"],
            "payload": {
                "english": {
                    "news": bbcode
                }
            }
        }
    }
    
    # Cache the result
    with open(CACHE_FILE, 'w') as f:
        f.write(json.dumps(changelog))
    
    return changelog

class ProxyRequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if "steamos-release-notes" in self.path:
            try:
                changelog = get_bazzite_changelog()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(changelog).encode('utf-8'))
            except Exception as e:
                print(f"Error handling request: {e}", file=sys.stderr)
                self.send_response(500)
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                self.wfile.write(f"Error: {e}".encode('utf-8'))
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"Not found")
    
    # Suppress logs to stderr
    def log_message(self, format, *args):
        return

def main():
    PORT = 8080
    print(f"Bazzite changelog proxy server starting on http://127.0.0.1:{PORT}")
    with socketserver.TCPServer(("127.0.0.1", PORT), ProxyRequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("Shutting down server")
            httpd.shutdown()

if __name__ == "__main__":
    main()