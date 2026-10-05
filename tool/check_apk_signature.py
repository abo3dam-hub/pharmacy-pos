#!/usr/bin/env python3
"""Fail the build unless the APK was signed by the given keystore.

CI restores ANDROID_KEYSTORE_B64 to ~/.android/debug.keystore before
`flutter build apk`. Newer AGP silently ignores a merely placed
~/.android/debug.keystore and generates a fresh key per build, which makes
Android refuse in-place updates ("package conflicts with an existing
package"). This check compares the keystore's certificate fingerprint with
the APK signing-block's signer certificate fingerprint and fails loudly
instead of shipping a randomly-signed APK.

Usage:
    check_apk_signature.py <keystore> <apk> [storepass]
"""

from __future__ import annotations

import struct
import subprocess
import sys


def keystore_fingerprint(keystore: str, storepass: str) -> str:
    p = subprocess.run(
        [
            "keytool",
            "-list",
            "-v",
            "-keystore",
            keystore,
            "-storepass",
            storepass,
        ],
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        raise RuntimeError(f"keytool failed on {keystore}:\n{p.stderr[-2000:]}")
    for line in p.stdout.splitlines():
        line = line.strip()
        if line.startswith("SHA256:"):
            return line.split("SHA256:", 1)[1].strip()
    raise RuntimeError(f"no SHA256 fingerprint in keytool output for {keystore}")


def apk_signer_fingerprint(apk: str) -> str:
    with open(apk, "rb") as f:
        data = f.read()
    eocd = data.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise RuntimeError(f"{apk}: no ZIP end-of-central-directory found")
    cd_offset = struct.unpack_from("<I", data, eocd + 16)[0]
    if data[cd_offset - 16 : cd_offset] != b"APK Sig Block 42":
        raise RuntimeError(f"{apk}: no APK signing block found")
    block_size = struct.unpack_from("<Q", data, cd_offset - 24)[0]
    block = data[cd_offset - 24 - block_size : cd_offset - 16]
    i = block.find(b"\x30\x82")  # DER SEQUENCE, long-form length
    while i >= 0:
        length = struct.unpack_from(">H", block, i + 2)[0]
        blob = block[i : i + 4 + length]
        if len(blob) == 4 + length:
            p = subprocess.run(
                [
                    "openssl",
                    "x509",
                    "-inform",
                    "DER",
                    "-noout",
                    "-fingerprint",
                    "-sha256",
                ],
                input=blob,
                capture_output=True,
            )
            if p.returncode == 0:
                out = p.stdout.decode().strip()
                if out.startswith("sha256 Fingerprint="):
                    return out.split("=", 1)[1].strip()
        i = block.find(b"\x30\x82", i + 1)
    raise RuntimeError(f"{apk}: no signer certificate found in signing block")


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__.strip().splitlines()[-3:])
        return 2
    keystore, apk = sys.argv[1], sys.argv[2]
    storepass = sys.argv[3] if len(sys.argv) > 3 else "android"
    try:
        want = keystore_fingerprint(keystore, storepass)
        got = apk_signer_fingerprint(apk)
    except RuntimeError as e:
        print(f"SIGNATURE CHECK FAILED: {e}")
        return 1
    print(f"keystore cert : {want}")
    print(f"APK signer    : {got}")
    if want != got:
        print(
            "SIGNATURE CHECK FAILED: APK was NOT signed by the stable "
            "keystore (each build got a fresh random key; Android would "
            "refuse it as an update)."
        )
        return 1
    print("SIGNATURE CHECK PASSED: APK signed by the stable keystore.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
