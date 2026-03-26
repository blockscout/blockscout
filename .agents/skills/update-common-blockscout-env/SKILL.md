---
name: update-common-blockscout-env
description: Ensure every newly introduced environment variable is also added to docker-compose/envs/common-blockscout.env so local Docker setups stay aligned with runtime configuration.
---

## Overview

This skill keeps environment-variable documentation and defaults in sync for Docker users.

When adding or changing runtime env vars (for example in config/runtime.exs), also update docker-compose/envs/common-blockscout.env in the same task.

## Mandatory Rule

- Every new env variable introduced in code/config must be added to docker-compose/envs/common-blockscout.env.
- Do not postpone this to a follow-up task.

## How To Apply

1. Identify newly added env vars in changed files (typically config/runtime.exs, config/*.exs, or modules reading System.get_env/1-2).
2. Add each variable to docker-compose/envs/common-blockscout.env.
3. Place it in the most relevant section (for example API flags near other API_* variables).
4. Prefer non-breaking defaults:
   - Use a commented example line for optional flags (for example # MY_FLAG=false).
   - Use an uncommented value only when the project convention requires a default to be active.
5. Keep naming and formatting consistent with existing entries.

## Checklist

- New env var exists in code.
- Matching entry exists in docker-compose/envs/common-blockscout.env.
- Placement is logical and discoverable.
- Default value does not change behavior unexpectedly.

## Example

If code adds:

- DISABLE_TRANSACTIONS_BENS_PRELOAD

Then docker-compose/envs/common-blockscout.env should include:

- # DISABLE_TRANSACTIONS_BENS_PRELOAD=false
