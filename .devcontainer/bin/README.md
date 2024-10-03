# Blockscout Backend Development with VSCode Devcontainers and GitHub Codespaces

## Table of Contents
1. [Motivation](#motivation)
2. [Setting Up VSCode Devcontainer Locally](#setting-up-vscode-devcontainer-locally)
3. [Using GitHub Codespaces in the Browser](#using-github-codespaces-in-the-browser)
4. [Configuring Postgres DB Access](#configuring-postgres-db-access)
5. [Developing Blockscout Backend](#developing-blockscout-backend)
6. [Upgrading Elixir Version](#upgrading-elixir-version)
7. [Contributing](#contributing)

## Motivation

Setting up a local development environment for Blockscout can be time-consuming and error-prone. This devcontainer setup streamlines the process by providing a pre-configured environment with all necessary dependencies. It ensures consistency across development environments, reduces setup time, and allows developers to focus on coding rather than configuration.

Key benefits include:
- Pre-configured environment with Elixir, Phoenix, and Node.js
- Integrated PostgreSQL database
- Essential VS Code extensions pre-installed
- Simplified database management
- Consistent development environment across team members

## Setting Up VSCode Devcontainer Locally

1. Clone the Blockscout repository:
   ```
   git clone https://github.com/blockscout/blockscout.git
   cd blockscout
   ```

2. Open the project in VS Code:
   ```
   code .
   ```

3. Before re-opening in the container, you may find it useful to configure SSH authorization. To do this:
   
   a. Ensure you have SSH access to GitHub configured on your local machine.
   
   b. Open `.devcontainer/devcontainer.json`.
   
   c. Uncomment the `mounts` section:
      ```json
      "mounts": [
        "source=${localEnv:HOME}/.ssh/known_hosts,target=/home/vscode/.ssh/known_hosts,type=bind,consistency=cached",
        "source=${localEnv:HOME}/.ssh/config,target=/home/vscode/.ssh/config,type=bind,consistency=cached",
        "source=${localEnv:HOME}/.ssh/id_rsa,target=/home/vscode/.ssh/id_rsa,type=bind,consistency=cached"
      ],
      ```
   
   d. Adjust the paths if your SSH keys are stored in a different location.

4. When prompted, click "Reopen in Container". If not prompted, press `F1`, type "Remote-Containers: Reopen in Container", and press Enter.

5. VS Code will build the devcontainer. This process includes:
   - Pulling the base Docker image
   - Installing specified VS Code extensions
   - Setting up the PostgreSQL database
   - Installing project dependencies
   
   This may take several minutes the first time.

6. Once the devcontainer is built, you'll be working inside the containerized environment.

### Signing in to GitHub for Pull Request Extension

1. In the devcontainer, click on the GitHub icon in the Primary sidebar.
2. Click on "Sign in to GitHub" and follow the prompts to authenticate.

## Using GitHub Codespaces in the Browser

To open the project in GitHub Codespaces:

1. Navigate to the Blockscout repository on GitHub.
2. Switch to the branch you want to work on.
3. Click the "Code" button.
4. Instead of clicking "Create codespace on [branch]" (which would use the default machine type that may not be sufficient for this Elixir-based project), click on the three dots (...) next to it.
5. Select "New with options".
6. Choose the "4-core/16GB RAM" machine type for optimal performance.
7. Click "Create codespace".

This will create a new Codespace with the specified resources, ensuring adequate performance for the Elixir-based project.

Note: After the container opens, you may see an error about the inability to use "GitHub Copilot Chat". This Copilot functionality will not be accessible in the Codespace environment.

## Configuring Postgres DB Access

To configure access to the PostgreSQL database using the VS Code extension:

1. Click on the PostgreSQL icon in the Primary sidebar.
2. Click "+" (Add Connection) in the PostgreSQL explorer.
3. Use the following details:
   - Host: `db`
   - User: `postgres`
   - Password: `postgres`
   - Port: `5432`
   - Use an ssl connection: "Standard connection"
   - Database: `blockscout`
   - The display name: "<some name>"

These credentials are derived from the `DATABASE_URL` in the `bs` script.

## Developing Blockscout Backend

### Configuration

Before running the Blockscout server, you need to set up the configuration:

1. Copy the `.blockscout_config.example` file to `.blockscout_config`.
2. Adjust the settings in `.blockscout_config` as needed for your development environment.

For a comprehensive list of environment variables that can be set in this configuration file, refer to the [Blockscout documentation](https://docs.blockscout.com/setup/env-variables).

### Using the `bs` Script

The `bs` script in `.devcontainer/bin/` helps orchestrate common development tasks. Here are some key commands:

- Initialize the project: `bs --init`
- Initialize or re-initialize the database: `bs --db-init` (This will remove all data and tables from the DB and re-create the tables)
- Run the server: `bs`
- Run the server without syncing: `bs --no-sync`
- Recompile the project: `bs --recompile` (Use this when new dependencies arrive after a merge or when switching to another `CHAIN_TYPE`)
- Run various checks: `bs --spellcheck`, `bs --dialyzer`, `bs --credo`, `bs --format`

For a full list of options, run `bs --help`.

## Upgrading Elixir Version

To upgrade the Elixir version:

1. Open `.devcontainer/Dockerfile`.
2. Update the `VARIANT` argument with the desired Elixir version.
3. Rebuild the devcontainer.

Note: Ensure that the version you choose is compatible with the project dependencies.

After testing the new Elixir version, propagate the corresponding changes in the Dockerfile to the repo https://github.com/blockscout/devcontainer-elixir. Once a new release tag is published there and a new docker image `ghcr.io/blockscout/devcontainer-elixir` appears in the GitHub registry, modify the `docker-compose.yml` file in the `.devcontainer` directory to reflect the proper docker image tag.

## Contributing

When contributing changes that require additional checks for specific blockchain types:

1. Open `.devcontainer/bin/chain-specific-checks`.
2. Add your checks under the appropriate `CHAIN_TYPE` case.
3. Ensure your checks exit with a non-zero code if unsuccessful.

Remember to document any new checks or configuration options in this README.