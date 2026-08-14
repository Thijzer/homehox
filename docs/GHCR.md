# GHCR and bootc updates

## Image publication

`.github/workflows/publish-image.yml` builds the OCI image on pull requests
without pushing it. A push to `master` publishes `latest` and a commit tag.
Pushing a tag matching `v*.*.*` publishes the semantic version and updates the
`stable` channel. GitHub's `GITHUB_TOKEN` is used by Actions; no registry
password belongs in this repository.

The first package publication may be private depending on the repository's
GitHub package defaults. For unattended host updates, make the package public,
or configure a narrowly scoped read-only pull token on the host. A public
package is preferred for this appliance because the image contains no private
keys or passwords.

Check the published digests in GitHub: **Packages → homehox → Versions**. A
release is only complete once the expected version and digest are present.

## Updating an installed host

For a public GHCR package, copy the updater to the host and stage a release:

```bash
scp scripts/update-bootc.sh thijzer@HOST:/tmp/
ssh -t thijzer@HOST 'sudo bash /tmp/update-bootc.sh \
  --image ghcr.io/thijzer/homehox:v1.2.3'
```

Review `bootc status`, then reboot during the change window:

```bash
ssh -t thijzer@HOST 'sudo systemctl reboot'
```

Or combine staging and reboot with `--reboot`. The updater uses `bootc switch`,
which changes the image source and stages a transactional deployment. The
currently running deployment remains active until reboot.

For normal channel updates:

```bash
sudo bash /tmp/update-bootc.sh --image ghcr.io/thijzer/homehox:stable
```

Exact version tags are preferable when rolling out gradually. `latest` is for
development and must not be used on production hosts.

## Private package authentication

Authenticate the container registry on the host before switching:

```bash
read -r -s GHCR_TOKEN
printf '%s' "$GHCR_TOKEN" | sudo podman login ghcr.io \\
  --username GITHUB_USER --password-stdin
unset GHCR_TOKEN
```

Use a GitHub token with only package-read access, store the resulting registry
credentials with the host's normal root permissions, and rotate it. Never put
the token in a command recorded in shell history, a Compose file, or this
repository. Confirm that the bootc/container storage used by the host can read
the registry credentials before the maintenance window.

## Automation plan

The safe progression is:

1. **Now:** GitHub Actions builds on PRs and publishes immutable commit and
   release tags.
2. **After VM testing:** a protected `v*` tag is the only action that moves
   `stable`.
3. **Staging:** a scheduled or manually dispatched job can notify that a new
   `stable` digest exists; it should not reboot production automatically.
4. **Adoption:** hosts may run a timer that checks `bootc upgrade --check` and
   records availability, while reboot approval remains explicit.
5. **Later:** use a fleet tool or maintenance-window automation to call the
   updater on a selected host group, verify `bootc status` and health checks,
   then continue to the next host.

Do not make GHCR's moving tag the only audit trail. Record the exact version or
digest, test result, deployment host, reboot time, and rollback result.
