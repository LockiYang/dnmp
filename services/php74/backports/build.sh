#!/usr/bin/env bash
set -euo pipefail

# Build a replacement base image; the existing DNMP Dockerfile adds extensions.
PHP_SOURCE_COMMIT=9f3f6763497aa556d3fc56df7e66f44b8de49815
DOCKER_LIBRARY_COMMIT=b9f17156020c3aef71df681b27684533529347a7
IMAGE="${PHP74_BACKPORTS_IMAGE:-dnmp/php74-base:7.4.33-backports-9f3f6763497a}"

for tool in curl python3 docker; do
    command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2; exit 1; }
done
docker info >/dev/null

build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

official_url="https://raw.githubusercontent.com/docker-library/php/${DOCKER_LIBRARY_COMMIT}/7.4/alpine3.16/fpm"
for file in Dockerfile docker-php-source docker-php-entrypoint docker-php-ext-configure docker-php-ext-enable docker-php-ext-install; do
    curl --fail --location --show-error --retry 3 \
        "${official_url}/${file}" -o "${build_dir}/${file}"
done
chmod +x "$build_dir"/docker-php-*

curl --fail --location --show-error --retry 3 \
    "https://codeload.github.com/shivammathur/php-src-backports/tar.gz/${PHP_SOURCE_COMMIT}" \
    -o "${build_dir}/php.tar.gz"

python3 - "$build_dir" "$PHP_SOURCE_COMMIT" <<'PY'
import gzip
import hashlib
import lzma
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1])
commit = sys.argv[2]
# docker-php-source expects an xz archive with one enclosing directory.
with gzip.open(root / 'php.tar.gz', 'rb') as src, lzma.open(root / 'php.tar.xz', 'wb') as dst:
    shutil.copyfileobj(src, dst)
(root / 'php.tar.gz').unlink()
digest = hashlib.sha256((root / 'php.tar.xz').read_bytes()).hexdigest()

path = root / 'Dockerfile'
text = path.read_text()
start = text.index('ENV GPG_KEYS ')
end = text.index('COPY docker-php-source ', start)
text = text[:start] + (
    'ENV PHP_VERSION=7.4.33\n'
    f'ENV PHP_BACKPORTS_COMMIT={commit}\n'
    f'LABEL org.opencontainers.image.revision="{commit}"\n'
    'LABEL org.opencontainers.image.source="https://github.com/shivammathur/php-src-backports"\n'
    f'LABEL dnmp.php.source-archive-sha256="{digest}"\n'
    'COPY php.tar.xz /usr/src/php.tar.xz\n\n'
) + text[end:]
# Git archives lack the generated configure script in official release tarballs.
needle = '\t\targon2-dev \\\n'
assert text.count(needle) == 1
text = text.replace(needle, needle + '\t\tbison \\\n')
needle = '\tcd /usr/src/php; \\\n'
assert text.count(needle) == 1
text = text.replace(needle, needle + '\t./buildconf --force; \\\n')
path.write_text(text)
print(f'PHP source commit: {commit}')
print(f'Archive SHA256: {digest}')
PY

docker build --progress=plain -t "$IMAGE" "$build_dir"
docker run --rm "$IMAGE" php -v
docker run --rm "$IMAGE" php-fpm -t
printf '\nBase image ready: %s\n' "$IMAGE"
