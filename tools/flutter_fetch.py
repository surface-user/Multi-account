#!/usr/bin/env python3
"""Fetch Flutter SDK metadata & optionally download the Windows stable zip.

Uses Python's OpenSSL-based TLS (bypasses broken Windows Schannel on this host).
"""
import hashlib
import json
import os
import sys
import time
import urllib.request

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

MIRRORS = [
    'https://storage.flutter-io.cn/flutter_infra_release/releases/releases_windows.json',
    'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json',
]


def fetch(url, timeout=30, retries=4):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2 * (i + 1))
    raise RuntimeError('fetch failed for %s: %s' % (url, last))


def find_meta(data):
    cur = data['current_release']['stable']
    for r in data['releases']:
        if r.get('channel') == 'stable' and r.get('version') == cur:
            return cur, r
    # Fallback: newest stable.
    stables = [r for r in data['releases'] if r.get('channel') == 'stable']
    stables.sort(key=lambda r: r.get('release_date') or '', reverse=True)
    return stables[0]['version'], stables[0]


def download(url, dest):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        total = int(r.headers.get('Content-Length') or 0)
        done = 0
        last_report = 0.0
        with open(dest, 'wb') as f:
            while True:
                chunk = r.read(1024 * 256)
                if not chunk:
                    break
                f.write(chunk)
                done += len(chunk)
                now = time.time()
                if now - last_report > 1.0:
                    pct = (done * 100.0 / total) if total else 0.0
                    sys.stderr.write('\r  %d/%d MB (%.1f%%)'
                                     % (done // (1024 * 1024), total // (1024 * 1024), pct))
                    last_report = now
    sys.stderr.write('\n')
    return done, total


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'meta'
    if mode == 'meta':
        for m in MIRRORS:
            try:
                raw = fetch(m)
                data = json.loads(raw)
                ver, rel = find_meta(data)
                base = data.get('base_url') or 'https://storage.flutter-io.cn/flutter_infra_release/releases'
                # Build the standard archive URL. Newer entries carry 'archive'; fall back to path.
                # The release 'archive' field already carries channel/OS dirs,
                # e.g. "stable/windows/flutter_windows_3.47.1-stable.zip".
                archive = rel.get('archive') or ''
                if not archive:
                    archive = rel.get('path') or ''
                if archive and not archive.endswith('.zip'):
                    archive = archive + '.zip'
                urlpath = archive
                meta = {
                    'version': ver,
                    'archive': archive,
                    'path': urlpath,
                    'sha256': rel.get('sha256'),
                    'url': base + '/' + urlpath,
                    'entry': rel,
                }
                with open('tools/flutter_meta.json', 'w', encoding='utf-8') as f:
                    json.dump(meta, f, ensure_ascii=False, indent=2)
                print('MIRROR_OK', m)
                print('VERSION', ver)
                print('PATH', urlpath)
                print('URL', meta['url'])
                print('SHA256', rel.get('sha256'))
                return
            except Exception as e:  # noqa: BLE001
                print('MIRROR_FAIL', m, e)
        sys.exit(1)
    elif mode == 'download':
        url = sys.argv[2]
        dest = sys.argv[3]
        done, total = download(url, dest)
        print('DOWNLOADED', dest, done, total)
    elif mode == 'sha256':
        print(sha256_file(sys.argv[2]))
    else:
        print('unknown mode', mode)
        sys.exit(1)


if __name__ == '__main__':
    main()
