defmodule Explorer.Repo.Migrations.LogsTransferPartialIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :logs,
        [:block_number,:transaction_hash,:index],
        name: "logs_erc20_transfers_filtered",
        where: "first_topic='0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'"
      )
    )
  end
end
