#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'This staging cleanup supports macOS only.' >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <staging-root>\n' "$0" >&2
  exit 1
fi
if ! command -v python3 >/dev/null; then
  printf '%s\n' 'python3 is required for descriptor-safe staging cleanup.' >&2
  exit 1
fi

# The helper opens the root with O_NOFOLLOW, checks the marker through that
# descriptor, and removes descendants through descriptor-relative operations.
# It refuses a pathname replacement before the final rmdir rather than
# recursively deleting a replacement directory.
exec python3 - "${TMPDIR:?TMPDIR must be set on macOS}" "$1" <<'PY'
import errno
import os
import stat
import sys

MARKER_NAME = '.agents-config-helper-test-root'
MARKER_CONTENTS = b'agents-config-helper staging root v1'
PREFIX = 'agents-config-helper-staging.'
NOFOLLOW_DIRECTORY = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def stat_at(directory_fd, name):
    return os.stat(name, dir_fd=directory_fd, follow_symlinks=False)


def same_file(first, second):
    return first.st_dev == second.st_dev and first.st_ino == second.st_ino


def read_all(descriptor):
    chunks = []
    while True:
        chunk = os.read(descriptor, 8192)
        if not chunk:
            return b''.join(chunks)
        chunks.append(chunk)


def remove_contents(directory_fd):
    for name in os.listdir(directory_fd):
        if name in ('.', '..'):
            continue
        entry = stat_at(directory_fd, name)
        if stat.S_ISDIR(entry.st_mode):
            try:
                child_fd = os.open(name, NOFOLLOW_DIRECTORY, dir_fd=directory_fd)
            except OSError as error:
                fail(f'Refusing to traverse {name!r}: {error.strerror}')
            try:
                if not same_file(entry, os.fstat(child_fd)):
                    fail(f'Refusing to traverse a replaced directory: {name!r}')
                remove_contents(child_fd)
            finally:
                os.close(child_fd)
            if not same_file(entry, stat_at(directory_fd, name)):
                fail(f'Refusing to remove a replaced directory: {name!r}')
            os.rmdir(name, dir_fd=directory_fd)
        else:
            os.unlink(name, dir_fd=directory_fd)


temporary_parent, input_root = sys.argv[1:]
parent_path = os.path.realpath(temporary_parent)
input_path = os.path.abspath(input_root)
input_parent = os.path.realpath(os.path.dirname(input_path))
root_name = os.path.basename(input_path)
if input_parent != parent_path or not root_name.startswith(PREFIX):
    fail('Refusing to remove a path outside the script-created staging prefix.')

try:
    parent_fd = os.open(parent_path, NOFOLLOW_DIRECTORY)
except OSError as error:
    fail(f'Unable to open the temporary-directory parent: {error.strerror}')

try:
    try:
        root_fd = os.open(root_name, NOFOLLOW_DIRECTORY, dir_fd=parent_fd)
    except OSError as error:
        fail(f'Refusing to open the staging root: {error.strerror}')
    try:
        root_stat = os.fstat(root_fd)
        marker_fd = os.open(MARKER_NAME, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=root_fd)
        try:
            if not stat.S_ISREG(os.fstat(marker_fd).st_mode):
                fail('Refusing to remove a root without a regular staging marker.')
            if read_all(marker_fd) != MARKER_CONTENTS:
                fail('Refusing to remove a root with an unexpected staging marker.')
        finally:
            os.close(marker_fd)

        remove_contents(root_fd)
        try:
            current_root = stat_at(parent_fd, root_name)
        except FileNotFoundError:
            fail('Staging root was replaced or removed during cleanup.')
        if not same_file(root_stat, current_root):
            fail('Staging root was replaced during cleanup; refusing final removal.')
        os.rmdir(root_name, dir_fd=parent_fd)
    finally:
        os.close(root_fd)
finally:
    os.close(parent_fd)

print(f'Removed staging root: {os.path.join(parent_path, root_name)}')
PY
