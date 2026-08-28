#!/usr/bin/env python3
"""Extract the Flutter SDK zip to a target directory."""
import os
import shutil
import sys
import zipfile


def extract(archive, dest):
    os.makedirs(dest, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        total = sum(i.file_size for i in z.infolist())
        done = 0
        for name in z.namelist():
            # sanity: prevent path traversal
            target = os.path.join(dest, name)
            if not os.path.abspath(target).startswith(os.path.abspath(dest)):
                raise RuntimeError('unsafe path in zip: %s' % name)
        for info in z.infolist():
            z.extract(info, dest)
            done += info.file_size
            if done % (100 * 1024 * 1024) < 10 * 1024 * 1024:
                print('extracted %d MB' % (done // (1024 * 1024)), flush=True)
    print('DONE')


if __name__ == '__main__':
    archive = sys.argv[1]
    dest = sys.argv[2]
    extract(archive, dest)
