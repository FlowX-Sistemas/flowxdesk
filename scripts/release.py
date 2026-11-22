"""Publica uma versão do FlowXDesk nas Releases do GitHub, já pronta para a atualização automática.

Gera e sobe junto com os instaladores:
  flowxdesk-update.json      metadados (versão, URL, tamanho, sha256 de cada instalador)
  flowxdesk-update.json.sig  assinatura ed25519 dos metadados (o app Windows confere com a chave embutida)
  flowxdesk-version.json     {"url": ".../releases/tag/X.Y.Z"}: é o que o app consulta para saber se há versão nova

Uso (python SEM -I, precisa do pacote 'cryptography'):
  python scripts/release.py 1.5.3 --exe dist/FlowXDesk-1.5.3-x64.exe --apk dist/android/FlowXDesk-1.5.3-arm64.apk
  --key  chave privada PEM (padrão: D:\\Sistemas\\_segredos\\flowxdesk-update-ed25519.pem)
  --dry-run  só gera e confere os arquivos em build/release-X.Y.Z, sem publicar
"""
import argparse
import base64
import datetime
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import brand  # noqa: E402  (mesma chave pública/repo que vão embutidos no app)

CONTEXT = b"RustDesk update metadata v1\n"  # prefixo fixo do verificador do RustDesk (update_metadata.rs)
OWNER, REPO = brand.UPDATE_REPO


def artifact(path, platform, arch, fmt, version, name):
    data = path.read_bytes()
    return {
        "platform": platform, "arch": arch, "format": fmt,
        "url": f"https://github.com/{OWNER}/{REPO}/releases/download/{version}/{name}",
        "file_name": name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("version")
    ap.add_argument("--exe", type=pathlib.Path, required=True)
    ap.add_argument("--apk", type=pathlib.Path)
    ap.add_argument("--key", type=pathlib.Path, default=pathlib.Path(r"D:\Sistemas\_segredos\flowxdesk-update-ed25519.pem"))
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    v = a.version
    if not re.fullmatch(r"\d+\.\d+\.\d+", v):
        sys.exit("versão deve ser X.Y.Z")

    out = ROOT / "build" / f"release-{v}"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    files = []
    arts = []
    exe_name = f"FlowXDesk-{v}-x64.exe"
    shutil.copyfile(a.exe, out / exe_name)
    files.append(out / exe_name)
    arts.append(artifact(out / exe_name, "windows", "x86_64", "exe", v, exe_name))
    if a.apk:
        apk_name = f"FlowXDesk-{v}-arm64.apk"
        shutil.copyfile(a.apk, out / apk_name)
        files.append(out / apk_name)
        arts.append(artifact(out / apk_name, "android", "aarch64", "apk", v, apk_name))

    meta = {
        "schema_version": 1, "app": "flowxdesk", "package_id": "flowxdesk",
        "version": v, "release_id": v,
        "published_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "signature_key_id": brand.UPDATE_KEY_ID, "artifacts": arts,
    }
    meta_bytes = json.dumps(meta, indent=2).encode()
    key = serialization.load_pem_private_key(a.key.read_bytes(), password=None)
    sig = key.sign(CONTEXT + meta_bytes)
    # confere com a chave pública que está embutida no app; se não bater, o app recusaria a atualização
    Ed25519PublicKey.from_public_bytes(bytes(brand.UPDATE_PUBLIC_KEY)).verify(sig, CONTEXT + meta_bytes)

    (out / "flowxdesk-update.json").write_bytes(meta_bytes)
    (out / "flowxdesk-update.json.sig").write_text(json.dumps({
        "schema_version": 1, "algorithm": "ed25519", "key_id": brand.UPDATE_KEY_ID,
        "signature": base64.b64encode(sig).decode(),
    }, indent=2))
    (out / "flowxdesk-version.json").write_text(json.dumps(
        {"url": f"https://github.com/{OWNER}/{REPO}/releases/tag/{v}"}))
    files += [out / "flowxdesk-update.json", out / "flowxdesk-update.json.sig", out / "flowxdesk-version.json"]
    for f in files:
        print(f"  {f.name}  {f.stat().st_size} bytes")
    if a.dry_run:
        print(f"dry-run: arquivos em {out}")
        return
    subprocess.run(["gh", "release", "create", v, "-R", f"{OWNER}/{REPO}", "--title", f"FlowXDesk {v}",
                    "--notes", f"FlowXDesk {v} (baseado no RustDesk). Os apps instalados atualizam sozinhos.",
                    "--latest", *map(str, files)], check=True)
    print("publicado")


if __name__ == "__main__":
    main()
