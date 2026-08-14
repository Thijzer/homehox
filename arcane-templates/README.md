# Arcane templates

This directory is a small Arcane template registry for this project.

## Registry URL

Once this repository is public on GitHub, add the following URL in Arcane:

```text
https://raw.githubusercontent.com/Thijzer/homebox/master/arcane-templates/registry.json
```

The repository is currently `Thijzer/homebox` and its default branch is
`master`. If either changes, update the URLs in `registry.json` before adding
it to Arcane.

## Adding a template

Each template belongs in `templates/<id>/` and should include:

- `compose.yaml`
- `.env.example`
- `template.json`
- optionally `README.md`

The registry follows the [Arcane Templates Registry Schema](https://github.com/getarcaneapp/templates/blob/main/schema.json).
Keep secrets out of both the registry and committed environment files.

The current registry entry's `content_hash` is a SHA-256 fingerprint of the
four Tailscale source files. Recalculate it whenever those files change and
update the registry entry before publishing.
