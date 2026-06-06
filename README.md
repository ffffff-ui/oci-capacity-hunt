# oci-capacity-hunt

Auto-launches an Oracle Cloud **Always-Free ARM** (VM.Standard.A1.Flex, 2 OCPU / 12 GB)
instance in the Chuncheon region the moment capacity frees up — so a laptop doesn't
have to stay on retrying. Intended host for a self-hosted [Postiz](https://github.com/gitroomhq/postiz-app)
(free Buffer alternative).

- Runs every 15 min via GitHub Actions (free, unlimited on public repos).
- On `Out of host capacity`: quiet no-op, tries again next run.
- On success: launches the VM with the pre-registered SSH key and pings Discord.
- Self-stops once a non-terminated `postiz` instance exists.

All Oracle credentials live in encrypted GitHub Secrets — nothing sensitive is in this repo.
