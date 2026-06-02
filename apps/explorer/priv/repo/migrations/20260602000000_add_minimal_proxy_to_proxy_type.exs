# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.AddMinimalProxyToProxyType do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE proxy_type ADD VALUE 'minimal_proxy'")
  end
end
