#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
keystore_path="$project_dir/android/upload-keystore.jks"
properties_path="$project_dir/android/key.properties"
keytool_bin="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"

if [[ -e "$keystore_path" || -e "$properties_path" ]]; then
  echo "Upload signing files already exist; no files were changed." >&2
  exit 1
fi

if [[ ! -x "$keytool_bin" ]]; then
  echo "Android Studio keytool was not found at: $keytool_bin" >&2
  exit 1
fi

keystore_password="$(openssl rand -hex 32)"
umask 077

"$keytool_bin" -genkeypair -noprompt \
  -keystore "$keystore_path" \
  -storetype JKS \
  -alias upload \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -dname "CN=Palliative App Upload, OU=Mobile, O=Osperb, L=Kozhikode, ST=Kerala, C=IN" \
  -storepass "$keystore_password" \
  -keypass "$keystore_password"

{
  printf 'storePassword=%s\n' "$keystore_password"
  printf 'keyPassword=%s\n' "$keystore_password"
  printf 'keyAlias=upload\n'
  printf 'storeFile=../upload-keystore.jks\n'
} > "$properties_path"

unset keystore_password

echo "Created the ignored upload keystore and signing properties."
echo "Back up both android/upload-keystore.jks and android/key.properties securely."
