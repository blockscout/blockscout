defmodule Explorer.Repo.Arbitrum.Migrations.AddIndexForMessages do
  use Ecto.Migration

  def change do
    # name of the index is specified explicitly because the default index name is cut and not unique
    create(
      index(
        :arbitrum_crosslevel_messages,
        [:direction, :originating_transaction_block_number, :originating_transaction_hash],
        name: :arbitrum_crosslevel_messages_dir_block_hash
      )
    )
  end
end
