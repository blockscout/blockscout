# Branch Location Guide — `piyyy314/blockscout313`

## ✅ The `master` Branch Exists

The **`master`** branch is confirmed to exist in the `piyyy314/blockscout313` repository.

| Branch | SHA | Protected |
|--------|-----|-----------|
| `master` | `5a2f7b6f544dc8b7589a00b90495b3ca484b3590` | No |

---

## 📍 Finding the Branch in the GitHub UI

1. Go to **[https://github.com/piyyy314/blockscout313](https://github.com/piyyy314/blockscout313)**
2. On the repository home page, click the **branch dropdown** (shows the current branch name, e.g. `master` or `main`).
3. In the dropdown, type or scroll to find **`master`**.
4. Click **`master`** to switch to it.

**Direct link to the `master` branch:**
```
https://github.com/piyyy314/blockscout313/tree/master
```

**To compare `master` against another branch:**
```
https://github.com/piyyy314/blockscout313/compare/master
```

---

## 💻 Finding the Branch via Git Commands

### List all remote branches
```bash
git branch -r
```

### List all branches (local + remote)
```bash
git branch -a
```

### Confirm the `master` branch exists on the remote
```bash
git ls-remote --heads origin master
```

Expected output:
```
5a2f7b6f544dc8b7589a00b90495b3ca484b3590	refs/heads/master
```

### Check out the `master` branch locally
```bash
git fetch origin
git checkout master
# or (with newer git)
git switch master
```

### View the latest commit on `master`
```bash
git log origin/master --oneline -5
```

---

## 📋 All Branches in This Repository

As of the last investigation, the following branches exist:

| Branch Name |
|-------------|
| `master` |
| `copilot/report-branch-location` |
| `fix/pr-title-validation` |
| `snyk-fix-84aebf284611296a906e6234ac1d0894` |
| `snyk-upgrade-01e8524a29ac3d7422ee9cf83340ecd9` |
| `snyk-upgrade-6ec9e0d8c8e37ba40e01d97a20e47f46` |
| `snyk-upgrade-27c32341bd5824277d5f7f047089ac10` |
| `snyk-upgrade-94f330930111c1164431ef5947fb5d1b` |
| `snyk-upgrade-200f796ee1908031aa394c68f09b4fa7` |
| `dependabot/hex/absinthe-1.9.1` |
| `dependabot/hex/cbor-1.0.2` |
| `dependabot/hex/cldr_utils-2.29.5` |
| `dependabot/hex/credo-1.7.17` |
| `dependabot/hex/ecto_sql-3.13.5` |
| `dependabot/hex/ex_cldr-2.47.2` |
| `dependabot/hex/ex_cldr_numbers-2.38.1` |
| `dependabot/hex/ex_doc-0.40.1` |
| `dependabot/hex/ex_secp256k1-0.8.0` |
| `dependabot/hex/floki-0.38.1` |
| `dependabot/hex/hammer-7.2.0` |
| `dependabot/hex/image-0.63.0` |
| `dependabot/hex/phoenix-1.8.5` |
| `dependabot/hex/phoenix_live_view-1.1.27` |
| `dependabot/hex/plug_cowboy-2.8.0` |
| `dependabot/hex/prometheus_ex-5.1.0` |
| `dependabot/hex/telemetry-1.4.1` |
| `dependabot/hex/tesla-1.16.0` |
| `dependabot/hex/wallaby-0.30.12` |
| `dependabot/hex/ymlr-5.1.5` |
| `dependabot/npm_and_yarn/apps/block_scout_web/assets/npm_and_yarn-56d6a43482` |
