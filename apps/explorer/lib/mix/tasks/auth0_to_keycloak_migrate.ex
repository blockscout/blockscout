defmodule Mix.Tasks.Auth0ToKeycloakMigrate do
  @moduledoc """
  Migrates users from Auth0 to Keycloak.

  Reads all account identities with Auth0 UIDs, fetches their Auth0 user data,
  creates corresponding Keycloak users, and updates the identity UIDs.

  ## Usage

      mix auth0_to_keycloak_migrate [--dry-run] [--batch-size N]

  ## Options

    * `--dry-run` - Preview migration without making changes
    * `--batch-size` - Number of users per batch (default: 50)

  ## Prerequisites

  Both Auth0 and Keycloak must be configured via environment variables.
  Account access is automatically disabled during migration and re-enabled after.
  """

  use Mix.Task

  alias Explorer.Account.Auth0ToKeycloakMigration
  alias Mix.Task, as: MixTask

  @shortdoc "Migrate users from Auth0 to Keycloak"

  @impl MixTask
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [dry_run: :boolean, batch_size: :integer],
        aliases: [n: :dry_run, b: :batch_size]
      )

    MixTask.run("app.start")

    Auth0ToKeycloakMigration.run(opts)
  end
end
