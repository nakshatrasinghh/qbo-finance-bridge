# Developer installation

This guide gives every developer an independent QuickBooks Finance Bridge setup. The recommended path is the
interactive `bin/install` command; manual commands are included only as a fallback.

## What each developer needs

- Git
- Ruby 3.4.6
- PostgreSQL 16
- An Intuit Developer account
- A QuickBooks Online sandbox company

Node.js, npm, Yarn, and a separate frontend process are not required.

Ruby and Bundler have different version numbers:

- `3.4.6` is the Ruby version, declared in `.ruby-version`.
- Bundler is the Ruby dependency installer. Its compatible version is recorded in `Gemfile.lock`.

Developers do not need to select or type a Bundler version. `bin/install` reads the lockfile and installs the
required Bundler version automatically.

## 1. Install Ruby and PostgreSQL

One macOS setup option is:

```bash
brew install rbenv ruby-build postgresql@16
rbenv init
rbenv install -s 3.4.6
brew services start postgresql@16
```

Follow the instruction printed by `rbenv init` if shell configuration is required, then restart the terminal.

Linux developers can use rbenv, asdf, mise, or their distribution's packages. Windows developers should use a
Ruby 3.4.6 environment that can run the repository's Bash and Ruby executables, such as WSL 2.

## 2. Create an Intuit app and sandbox

This portal work cannot be automated by the repository.

1. Sign in to the [Intuit Developer portal](https://developer.intuit.com/).
2. Create or open an app with the **QuickBooks Online Accounting** permission.
3. Open **Keys and credentials**.
4. Select **Development** and keep the page available; the installer will ask for its Client ID and Client
   Secret.
5. Create or select a QuickBooks Online sandbox company.
6. Add this Development redirect URI exactly:

   ```text
   http://localhost:3000/quickbooks/connections/callback
   ```

Do not use Production credentials. The application accepts only the QuickBooks sandbox environment.

## 3. Clone the repository

```bash
git clone https://github.com/nakshatrasinghh/qbo-finance-bridge.git
cd qbo-finance-bridge
ruby --version
```

Ruby `3.4.6` is required. If the last command reports another version and rbenv is installed, `bin/install`
automatically relaunches itself with Ruby 3.4.6. With another Ruby manager, activate 3.4.6 before continuing.

## 4. Run the installer

```bash
bin/install
```

The installer performs these steps:

1. uses Ruby 3.4.6, automatically through rbenv when available, and rejects other Ruby versions;
2. installs the Bundler version required by `Gemfile.lock` when necessary;
3. installs the project gems;
4. reuses a valid local credentials/master-key pair, or asks for the developer's Intuit Development Client ID
   and Client Secret;
5. generates the Rails secret and all three Active Record Encryption keys;
6. writes only encrypted credentials to `config/credentials.yml.enc`;
7. keeps `config/credentials.yml.enc` and `config/master.key` local and ignored by Git; and
8. creates or migrates the development and test PostgreSQL databases.

The Client Secret is hidden while it is entered in an interactive terminal. The installer does not print it or
write plaintext credentials to the repository.

If PostgreSQL cannot connect, confirm that PostgreSQL 16 is running and that the current operating-system user
has a matching local PostgreSQL role. A team-managed database may instead be selected with `DATABASE_URL`.

## What the generated encryption values mean

Developers do not need to invent or manually replace placeholders when using `bin/install`.

The installer generates:

- `config/master.key`: decrypts the local Rails credentials file;
- `active_record_encryption.primary_key`: encrypts stored QuickBooks access and refresh tokens;
- `active_record_encryption.deterministic_key`: Rails' deterministic encryption key;
- `active_record_encryption.key_derivation_salt`: derives encryption subkeys; and
- `secret_key_base`: signs and encrypts Rails application data.

These are application security keys, not values obtained from QuickBooks. The only values copied from Intuit are
the Development Client ID and Client Secret. The redirect URI is fixed by this application.

Never share or commit the credentials file, master key, generated encryption keys, Client Secret, access token,
or refresh token. If the master key is lost, its credentials file cannot be decrypted. If the Active Record
Encryption keys are replaced, previously stored OAuth tokens cannot be decrypted.

## 5. Start Rails and connect the sandbox

```bash
QUICKBOOKS_ENV=sandbox bin/dev
```

Open:

```text
http://localhost:3000/quickbooks/connections
```

Select **Connect QuickBooks**, authorize the developer's sandbox company, and return to the connection page.
Use **Inspect** to verify the connection before opening the finance dashboards.

## 6. Verify the installation

The installer can verify the local bundle, encrypted credentials, PostgreSQL connection, and application
configuration without changing QuickBooks:

```bash
bin/install --check
```

Run the repository quality and security checks:

```bash
bin/format check
RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop
bundle exec brakeman --no-pager
bundle exec bundler-audit check
bin/rails zeitwerk:check
```

While Rails is running:

```bash
curl -fsS http://localhost:3000/up
curl -fsS http://localhost:3000/health
```

API documentation is available at:

```text
http://localhost:3000/api-docs
```

## Manual credentials fallback

Use this only when `bin/install` cannot create local credentials.

First install the bundle:

```bash
bundle install
```

Generate encryption keys:

```bash
bin/rails db:encryption:init
```

Rails prints three real random values in an `active_record_encryption` YAML block. Copy that complete block
exactly. Do not replace its values with labels or example text.

Open the ignored local credentials:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

Paste the generated encryption block, preserve any generated `secret_key_base`, and add:

```yaml
quickbooks:
  client_id: PASTE_THE_INTUIT_DEVELOPMENT_CLIENT_ID
  client_secret: PASTE_THE_INTUIT_DEVELOPMENT_CLIENT_SECRET
  redirect_uri: http://localhost:3000/quickbooks/connections/callback
```

Save and close the editor, then prepare the databases:

```bash
bin/setup --skip-server
```

## Environment-variable alternative

Deployments and temporary sessions may inject values instead of reading local Rails credentials:

```bash
export QUICKBOOKS_ENV=sandbox
export QUICKBOOKS_CLIENT_ID='YOUR_DEVELOPMENT_CLIENT_ID'
export QUICKBOOKS_CLIENT_SECRET='YOUR_DEVELOPMENT_CLIENT_SECRET'
export QUICKBOOKS_REDIRECT_URI='http://localhost:3000/quickbooks/connections/callback'
export ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY='YOUR_PRIMARY_KEY'
export ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY='YOUR_DETERMINISTIC_KEY'
export ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT='YOUR_KEY_DERIVATION_SALT'
```

A deployment also needs its normal Rails secret and database configuration. Do not store real values in files
that may be copied, uploaded, or shared.

## Common setup failures

- **Wrong Ruby version:** enter the repository through the configured Ruby manager and confirm `ruby --version`
  reports 3.4.6.
- **Intuit redirect mismatch:** the Development redirect URI and Rails configuration must both be exactly
  `http://localhost:3000/quickbooks/connections/callback`.
- **Credentials cannot be decrypted:** the credentials file and master key do not match. Restore the developer's
  matching pair or move both aside and rerun `bin/install`.
- **QuickBooks configuration is missing:** rerun `bin/install` or add all three `quickbooks` entries manually.
- **Token encryption fails:** all three `active_record_encryption` values must be present and unchanged.
- **PostgreSQL cannot connect:** start PostgreSQL 16, configure the local role, or provide `DATABASE_URL`.
- **Port 3000 is occupied:** stop the other process before starting Rails so the registered redirect URI remains
  valid.

## Official references

- [Rails encrypted credentials](https://guides.rubyonrails.org/security.html#custom-credentials)
- [Intuit sandbox companies](https://developer.intuit.com/app/developer/qbo/docs/develop/sandboxes/manage-your-sandboxes)
- [Intuit Development redirect URIs](https://developer.intuit.com/app/developer/qbo/docs/develop/authentication-and-authorization/set-redirect-uri)
- [QuickBooks Online Accounting scope](https://developer.intuit.com/app/developer/qbo/docs/learn/scopes)
