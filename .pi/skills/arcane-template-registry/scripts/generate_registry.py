#!/usr/bin/env python3
"""Generate an Arcane registry from templates/<id> directories."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

COMPOSE_NAMES = ("compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml")
SLUG_RE = re.compile(r"^[a-z0-9-]+$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:[-+].*)?$")


def git_value(repo_root: Path, *args: str) -> str | None:
    try:
        return subprocess.check_output(["git", *args], cwd=repo_root, text=True).strip() or None
    except (OSError, subprocess.CalledProcessError):
        return None


def github_repo(remote: str) -> str | None:
    value = remote.removesuffix(".git")
    if value.startswith("git@github.com:"):
        return value.removeprefix("git@github.com:")
    parsed = urlparse(value)
    if parsed.hostname and parsed.hostname.lower() == "github.com":
        return parsed.path.lstrip("/")
    return None


def content_hash(template_dir: Path, compose_name: str) -> str:
    digest = hashlib.sha256()
    for name in ("template.json", compose_name, ".env.example", "README.md"):
        path = template_dir / name
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8")
        # Match the official Arcane community generator's hash format.
        digest.update(f"{name}\n{len(content)}\n".encode())
        digest.update(content.encode())
        digest.update(b"\n")
    return digest.hexdigest()


def bump_patch(version: str) -> str:
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)", version)
    if not match:
        return "1.0.0"
    major, minor, patch = (int(part) for part in match.groups())
    return f"{major}.{minor}.{patch + 1}"


def fail(message: str) -> None:
    raise ValueError(message)


def build(args: argparse.Namespace) -> tuple[dict, list[str]]:
    repo_root = Path(args.repo_root).resolve()
    registry_root = (repo_root / args.registry_root).resolve()
    templates_root = registry_root / "templates"
    registry_path = registry_root / "registry.json"
    if not templates_root.is_dir():
        fail(f"templates directory not found: {templates_root}")

    previous = {}
    if registry_path.is_file():
        try:
            previous = json.loads(registry_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail(f"invalid existing registry: {exc}")

    repo = args.github_repo or github_repo(git_value(repo_root, "remote", "get-url", "origin") or "")
    branch = args.branch or git_value(repo_root, "branch", "--show-current") or "master"
    if not repo:
        fail("GitHub repository not found; use --github-repo OWNER/REPOSITORY")

    template_entries = []
    for template_dir in sorted(path for path in templates_root.iterdir() if path.is_dir()):
        template_id = template_dir.name
        if not SLUG_RE.fullmatch(template_id):
            fail(f"invalid template id: {template_id!r}")
        meta_path = template_dir / "template.json"
        if not meta_path.is_file():
            fail(f"missing {meta_path}")
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail(f"invalid {meta_path}: {exc}")
        for key in ("name", "description", "version", "author"):
            if not isinstance(meta.get(key), str) or not meta[key].strip():
                fail(f"{meta_path} requires non-empty string {key!r}")
        if not SEMVER_RE.fullmatch(meta["version"]):
            fail(f"{meta_path} has invalid semver version: {meta['version']!r}")
        tags = meta.get("tags")
        if not isinstance(tags, list) or not tags or any(not isinstance(tag, str) or not tag for tag in tags):
            fail(f"{meta_path} requires non-empty string tags")
        if len(set(tags)) != len(tags):
            fail(f"{meta_path} contains duplicate tags")
        compose_path = next((template_dir / name for name in COMPOSE_NAMES if (template_dir / name).is_file()), None)
        if compose_path is None:
            fail(f"{template_dir} needs one of: {', '.join(COMPOSE_NAMES)}")
        if not (template_dir / ".env.example").is_file():
            fail(f"missing {template_dir / '.env.example'}")
        public_base = args.public_base.rstrip("/") if args.public_base else f"https://raw.githubusercontent.com/{repo}/{branch}/{args.registry_root}/templates"
        docs_base = args.docs_base.rstrip("/") if args.docs_base else f"https://github.com/{repo}/tree/{branch}/{args.registry_root}/templates"
        template_entries.append({
            "id": template_id,
            "name": meta["name"],
            "description": meta["description"],
            "version": meta["version"],
            "author": meta["author"],
            "compose_url": f"{public_base}/{template_id}/{compose_path.name}",
            "env_url": f"{public_base}/{template_id}/.env.example",
            "documentation_url": f"{docs_base}/{template_id}",
            "content_hash": content_hash(template_dir, compose_path.name),
            "tags": tags,
        })

    old_entries = {entry.get("id"): entry for entry in previous.get("templates", [])}
    changed = len(old_entries) != len(template_entries) or any(
        old_entries.get(entry["id"], {}).get("content_hash") != entry["content_hash"] for entry in template_entries
    )
    version = str(previous.get("version", args.version or "1.0.0"))
    if changed and not args.no_bump and previous:
        version = bump_patch(version)

    registry = {
        "$schema": args.schema,
        "name": previous.get("name", args.name),
        "description": previous.get("description", args.description),
        "version": version,
        "author": previous.get("author", args.author),
        "url": f"https://github.com/{repo}/tree/{branch}/{args.registry_root}",
        "templates": template_entries,
    }
    return registry, [f"repository: https://github.com/{repo}", f"branch: {branch}", f"templates: {len(template_entries)}", f"changed: {'yes' if changed else 'no'}"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--registry-root", default="arcane-templates")
    parser.add_argument("--github-repo", help="OWNER/REPOSITORY; inferred from origin when omitted")
    parser.add_argument("--branch", help="branch used in published URLs; inferred from Git when omitted")
    parser.add_argument("--public-base", help="base URL containing template files")
    parser.add_argument("--docs-base", help="base URL containing template documentation")
    parser.add_argument("--schema", default="https://github.com/getarcaneapp/templates/schema.json")
    parser.add_argument("--name", default="Homebox Templates")
    parser.add_argument("--description", default="Docker Compose templates for the Homebox self-hosting appliance.")
    parser.add_argument("--author", default="thijzer")
    parser.add_argument("--version", default="1.0.0")
    parser.add_argument("--no-bump", action="store_true", help="preserve the existing registry version")
    parser.add_argument("--check", action="store_true", help="validate and compare without writing")
    args = parser.parse_args()
    try:
        registry, summary = build(args)
        output = json.dumps(registry, indent=2) + "\n"
        path = Path(args.repo_root).resolve() / args.registry_root / "registry.json"
        if args.check:
            if not path.is_file() or path.read_text(encoding="utf-8") != output:
                print(f"registry is stale: {path}", file=sys.stderr)
                return 1
            print("registry is valid and up to date")
        else:
            path.write_text(output, encoding="utf-8")
            print(f"wrote {path}")
        print("; ".join(summary))
        return 0
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
