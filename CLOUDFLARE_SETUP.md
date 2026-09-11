# RAH AI Studios — Cloudflare Pages setup

This repository contains a static RAH Software Download Center in `site/`.

## One-time Cloudflare setup

1. Sign in to Cloudflare.
2. Open **Workers & Pages**.
3. Choose **Create application → Pages → Connect to Git** (wording can vary slightly as the dashboard evolves).
4. Authorize the **Cloudflare Workers and Pages** GitHub application.
5. Give it access only to `NilsRa73/rah-platform` if possible.
6. Select repository: `NilsRa73/rah-platform`.
7. Use these deployment settings:

| Setting | Value |
|---|---|
| Project name | `rah-ai-studios` |
| Production branch | `main` |
| Framework preset | `None` |
| Build command | `exit 0` |
| Build output directory | `site` |
| Root directory | repository root / blank |

8. Deploy.

Cloudflare will create a temporary hostname similar to `rah-ai-studios.pages.dev`.

## Deployment model

- Website: Cloudflare Pages
- Source: GitHub `main`
- Website files: `site/`
- Program binaries: GitHub Releases
- Large downloads later: Cloudflare R2 if needed

Every future push to `main` can automatically trigger a Cloudflare Pages deployment after Git integration is enabled.

## Custom domain later

When a domain is ready, open the Pages project and use **Custom domains → Set up a domain**. Keep the `pages.dev` hostname during initial testing.

## Security

`site/_headers` adds browser security headers. The page does not store Cloudflare API tokens, GitHub tokens, passwords, or other account secrets.

Do not commit Cloudflare API tokens to this repository. If API-driven deployment is added later, store credentials as protected Cloudflare/GitHub secrets instead.

## Downloads

Do not upload large `.exe`, `.zip`, or `.iso` files directly into Cloudflare Pages. Publish software through GitHub Releases and link the website to those release assets. The page automatically checks GitHub's public latest-release endpoint and displays the newest release when one exists.
