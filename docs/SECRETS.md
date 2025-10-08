# Secrets and Service Keys Management

This document describes how to handle secrets and service keys in this project, following production-ready security practices.

## General Principles

1. **Never commit secrets to version control**
2. **Use environment variables for all secrets**
3. **Use platform-provided tokens in CI/CD**
4. **Use secret managers in production deployments**
5. **Scope tokens with minimum necessary permissions**

## GitHub Token (GH_TOKEN)

### CI/CD (GitHub Actions)

**No manual configuration needed.** GitHub Actions automatically provides `github.token` with repository-scoped permissions:

```yaml
env:
  GH_TOKEN: ${{ github.token }}
```

This token:
- Is automatically generated for each workflow run
- Has permissions limited to the repository
- Expires after the workflow completes
- Cannot be leaked or misused outside the workflow

### Local Development

For scripts that use `gh` CLI (like `scripts/enforce_single_flight.sh`):

**Option 1: GitHub CLI Authentication (Recommended)**
```bash
gh auth login
```
This stores your token securely in the system keychain and makes it available to `gh` commands.

**Option 2: Manual Personal Access Token**
1. Generate a fine-grained Personal Access Token at: https://github.com/settings/tokens
2. Required scopes:
   - `repo` (for private repositories)
   - `public_repo` (for public repositories)
   - `pull_request:read` (for PR operations)
   - `workflow:read` (for workflow status)
3. Store in `.env.local`:
   ```bash
   GH_TOKEN=github_pat_...
   ```

**Never use `.env` for local secrets** - use `.env.local` which is gitignored.

### Production/Deployment

**Do not store GH_TOKEN in deployment services**. Instead:

- Use platform-provided tokens (e.g., GitHub Actions `github.token`, GitHub App installation tokens)
- For cross-repository operations, use GitHub Apps with minimal permissions
- Store additional tokens in the deployment platform's secret manager:
  - GitHub Actions: Repository Secrets
  - AWS: Secrets Manager or Parameter Store
  - GCP: Secret Manager
  - Azure: Key Vault
  - Vercel/Netlify: Environment Variables (encrypted)

## Other Service Keys

As you add integrations that require API keys:

### Development
1. Add placeholder to `.env.example`:
   ```bash
   SERVICE_NAME_API_KEY=
   ```

2. Document in this file:
   - Where to obtain the key
   - Required scopes/permissions
   - Storage location (`.env.local` for dev)

3. Access in code:
   ```typescript
   const apiKey = process.env.SERVICE_NAME_API_KEY;
   if (!apiKey) {
     throw new Error('SERVICE_NAME_API_KEY not set');
   }
   ```

### CI/CD
Store in GitHub Actions Secrets:
```yaml
env:
  SERVICE_NAME_API_KEY: ${{ secrets.SERVICE_NAME_API_KEY }}
```

### Production
Use your deployment platform's secret manager and reference as environment variables.

## File Structure

```
.env.example          # Template with all required vars (committed)
.env                  # Shared team config, no secrets (gitignored)
.env.local            # Local overrides with secrets (gitignored)
.env.*.local          # Environment-specific local secrets (gitignored)
```

## Security Checklist

- [ ] All secrets use environment variables
- [ ] `.env.example` exists with placeholders
- [ ] `.env`, `.env.local`, `.env.*.local` are in `.gitignore`
- [ ] No secrets in code, logs, or error messages
- [ ] CI uses platform-provided tokens
- [ ] Production uses secret managers
- [ ] Tokens have minimal required permissions
- [ ] Unused tokens are revoked

## Troubleshooting

### "gh: GH_TOKEN environment variable not set"
- Run `gh auth login` to authenticate
- Or set `GH_TOKEN` in your shell/`.env.local`

### "API rate limit exceeded"
- Ensure you're using an authenticated token
- Check token hasn't expired
- Verify token has required scopes

### "Permission denied" errors
- Verify token has necessary scopes
- For fine-grained PATs, check repository access settings
- Ensure token hasn't been revoked

## Further Reading

- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
