# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.GraphQL.Resolvers.TokenTransfer do
  @moduledoc false

  alias Absinthe.Relay.Connection
  alias Explorer.Chain.{Address, TokenTransfer}
  alias Explorer.{GraphQL, PagingOptions, Repo}

  def get_by(%{transaction_hash: _, log_index: _} = args, _) do
    GraphQL.get_token_transfer(args)
  end

  def get_by(_, %{token_contract_address_hash: token_contract_address_hash} = args, resolution) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    replica = Repo.replica()
    scam_opts = scam_token_opts(resolution)

    token_contract_address_hash
    |> GraphQL.list_token_transfers_query(scam_opts)
    |> Connection.from_query(&replica.all/1, connection_args, options(args))
  end

  def get_by(%Address{hash: address_hash}, args, resolution) do
    connection_args = Map.take(args, [:after, :before, :first, :last])

    replica = Repo.replica()
    scam_opts = scam_token_opts(resolution)

    # Incoming and outgoing transfers are merged with UNION, and Relay applies
    # OFFSET and LIMIT only to the merged rows. Without a bound of their own both
    # sides are read in full, while the page never needs more than the first
    # offset + limit + 1 rows of either.
    with {:ok, offset, limit} <- Connection.offset_and_limit_for_query(connection_args, options(args)) do
      paging_options = %PagingOptions{page_size: offset + limit + 1}

      address_hash
      |> TokenTransfer.token_transfers_by_address_hash(nil, nil, [], paging_options, scam_opts)
      |> Connection.from_query(&replica.all/1, connection_args, options(args))
    end
  end

  defp scam_token_opts(%{context: context}),
    do: [show_scam_tokens?: Map.get(context, :show_scam_tokens?, false)]

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
