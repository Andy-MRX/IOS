# PulseDeck GitHub Actions / Cloud CI

This document explains how to use the included GitHub Actions workflows to validate the project on every push and optionally export a signed IPA from GitHub-hosted macOS runners.

## Included workflows

### 1) `.github/workflows/pulsedeck-ci.yml`

Purpose:
- Open the Xcode project on a macOS runner
- Validate that the scheme/project can be listed
- Build the app for **iOS Simulator** without signing

This is the safest everyday CI workflow.

### 2) `.github/workflows/pulsedeck-ipa.yml`

Purpose:
- Import your Apple signing certificate
- Install your provisioning profile
- Archive `PulseDeck`
- Export a signed IPA
- Upload the IPA as a GitHub Actions artifact

This runs only by **manual trigger** (`workflow_dispatch`) because it requires secrets.

---

## What you need in GitHub Secrets

Set these in:

**GitHub repo → Settings → Secrets and variables → Actions**

### Required secrets for IPA export

- `PULSEDECK_BUNDLE_ID`
  - Current configured value: `xyz.appinstall.nov.carbon.lam`

- `PULSEDECK_DEVELOPMENT_TEAM`
  - Current configured value: `ZDV8SQG3XZ`

- `PULSEDECK_CERTIFICATE_P12_BASE64`
  - Your signing certificate exported as `.p12`, then base64 encoded

- `PULSEDECK_CERTIFICATE_PASSWORD`
  - Password used when exporting the `.p12`

- `PULSEDECK_PROVISIONING_PROFILE_BASE64`
  - Your `.mobileprovision` file base64 encoded

- `PULSEDECK_KEYCHAIN_PASSWORD`
  - Any strong temporary password for the CI keychain

- `PULSEDECK_EXPORT_OPTIONS_PLIST_BASE64`
  - A base64 encoded `ExportOptions.plist`
  - Current recommended file:
    - `export/ExportOptions-Enterprise-ZDV8SQG3XZ.plist`

---

## How to create base64 secrets

On macOS or Linux:

```bash
base64 -i certificate.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
base64 -i ExportOptions.plist | pbcopy
```

If `pbcopy` is unavailable, just output and paste manually:

```bash
base64 certificate.p12
base64 profile.mobileprovision
base64 ExportOptions.plist
```

---

## Recommended setup flow

### Step 1: Push the repo to GitHub

Push this project to your GitHub repository.

### Step 2: Let CI verify the project

Push any commit touching project files or workflow files.

GitHub will run `PulseDeck CI` automatically.

### Step 3: Configure signing secrets

Add all required secrets listed above.

### Step 4: Run IPA export manually

In GitHub:

- Open **Actions**
- Select **PulseDeck IPA Export**
- Click **Run workflow**

When it succeeds, download the artifact named:

- `PulseDeck-ipa`

---

## Notes / limits

- GitHub-hosted macOS runners can build and export iOS archives, but **your signing setup must be valid**.
- The simulator CI workflow does **not** produce an installable IPA.
- The IPA workflow is the one that can generate a signed package.
- If signing fails, common causes are:
  - wrong Team ID
  - wrong bundle identifier
  - provisioning profile mismatch
  - certificate/profile not matching each other

---

## Suggested next improvements

If you want to harden this setup later, add:

- automatic TestFlight upload
- separate dev / adhoc / app-store workflows
- reusable workflow inputs for bundle ID and export method
- Fastlane integration
