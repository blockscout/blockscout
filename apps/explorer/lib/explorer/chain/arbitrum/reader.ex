defmodule Explorer.Chain.Arbitrum.Reader do
  @moduledoc """
  TBD
  """

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 2,
      where: 2,
      where: 3
    ]

  alias Explorer.Chain.Arbitrum.Message

  alias Explorer.Repo

  @doc """
  TBD
  """
  def latest_completed_message_to_l2 do
    query =
      from(msg in Message,
        select: msg.originating_tx_blocknum,
        where: msg.direction == :to_l2 and not is_nil(msg.originating_tx_blocknum),
        order_by: [desc: msg.message_id],
        limit: 1
      )

    query
    |> Repo.one()
  end
end
