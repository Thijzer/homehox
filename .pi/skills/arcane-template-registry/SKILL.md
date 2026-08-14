---
name: arcane-template-registry
description: "Create, update, validate, and publish Arcane Docker Compose templates and registry.json entries. Use when adding an Arcane template, fixing registry URLs, generating registry metadata, or troubleshooting template download failures."
compatibility: "Requires Python 3.9+; Docker Compose is recommended for template validation."
metadata:
  author: thijzer
  version: 1.0.0
  category: deployment
  tags: [arcane, docker-compose, templates, registry]
---

# Arcane Template Registry

## Workflow

1. Work under `arcane-templates/` unless the user specifies another registry root.
2. Create `templates/<id>/` with:
   - one Compose file: `compose.yaml`, `compose.yml`, `docker-compose.yml`, or `docker-compose.yaml`;
   - `.env.example` with placeholders only;
   - `template.json` containing `name`, `description`, `version`, `author`, and non-empty `tags`;
   - optional `README.md` with prerequisites, ports, storage, security notes, and upstream documentation.
3. Never put passwords, API keys, auth keys, private keys, or production `.env` files in the template.
4. Run the bundled generator from the repository root:

   ```bash
   python3 .pi/skills/arcane-template-registry/scripts/generate_registry.py
   ```

   The generator discovers the GitHub owner/repository and current branch from Git, scans all template directories, calculates content hashes, validates metadata, and writes `arcane-templates/registry.json`.
5. If Git metadata is unavailable or the registry is hosted somewhere other than the repository's raw GitHub content, supply explicit values:

   ```bash
   python3 .pi/skills/arcane-template-registry/scripts/generate_registry.py \
     --repo-root . \
     --registry-root arcane-templates \
     --branch master \
     --github-repo Thijzer/homehox
   ```
6. Validate the generated registry and templates:

   ```bash
   python3 .pi/skills/arcane-template-registry/scripts/generate_registry.py --check
   python3 -m json.tool arcane-templates/registry.json >/dev/null
   docker compose --env-file templates/<id>/.env.example \
     -f templates/<id>/<compose-file> config >/dev/null
   ```

7. Inspect every generated URL. For a public GitHub registry, verify the registry, Compose, and `.env.example` URLs return HTTP 200 before telling the user to add the registry to Arcane.
8. When a repository is renamed or its default branch changes, regenerate the registry and re-add or refresh the registry URL in Arcane. Arcane may retain the old manifest and stale template URLs.

## Arcane-specific constraints

- Registry entries require `id`, `name`, `description`, `version`, `author`, `compose_url`, `env_url`, `documentation_url`, `content_hash`, and `tags`.
- IDs must be lowercase alphanumeric hyphen slugs. Tags must be non-empty and unique.
- Use pinned or explicitly configurable image tags; avoid silently introducing `latest`.
- Review privileged mode, capabilities, host networking, host bind mounts, Docker socket mounts, exposed ports, and devices as security-sensitive.
- `content_hash` detects source changes; it is not a cryptographic signature or a substitute for reviewing Compose content.
- Do not deploy, push, or modify Arcane registry configuration as an external side effect without user approval.

## Recovery

- **HTTP 404:** check repository owner/name, branch, path, case, and whether the latest commit was pushed. Regenerate instead of hand-editing individual URLs.
- **Registry loads but download fails:** test `compose_url` and `env_url` directly; both must point to raw file content, not GitHub HTML pages.
- **Compose validation fails:** fix the template before generating or publishing the registry.
- **Missing auth or secret:** leave a documented placeholder and require the value in Arcane's project environment.

## Output

Report the template directory, generated registry path, registry version, validation results, and any URLs or Git metadata that still require user action.
