defmodule Indexer.Fetcher.Signet.ReorgHandler do
  @moduledoc """
  Handles chain reorganizations for Signet order and fill data.

  When a chain reorg is detected, this module removes all orders and fills
  from blocks that are no longer in the canonical chain, allowing them to
  be re-indexed from the new canonical blocks.
  """

  require Logger

  import Ecto.Query

  alias Explorer.Chain.Signet.{Order, Fill}
  alias Explorer.Repo

  @doc """
  Handle a chain reorganization starting from the given block number.

  Deletes all orders and fills at or after the reorg block, allowing
  the fetcher to re-process these blocks.

  ## Parameters
    - from_block: The block number where the reorg was detected
    - chain_type: :rollup for L2 reorgs (affects orders and rollup fills),
                  :host for L1 reorgs (affects host fills only)

  ## Returns
    - :ok
  """
  @spec handle_reorg(non_neg_integer(), :rollup | :host) :: :ok
  def handle_reorg(from_block, chain_type) do
    Logger.info("Handling #{chain_type} chain reorg from block #{from_block}")

    case chain_type do
      :rollup ->
        handle_rollup_reorg(from_block)

      :host ->
        handle_host_reorg(from_block)
    end

    :ok
  end

  # Handle reorg on the rollup (L2) chain
  # This affects both orders and rollup fills
  defp handle_rollup_reorg(from_block) do
    # Delete orders at or after the reorg block
    {deleted_orders, _} =
      Repo.delete_all(
        from(o in Order,
          where: o.block_number >= ^from_block
        )
      )

    # Delete rollup fills at or after the reorg block
    {deleted_fills, _} =
      Repo.delete_all(
        from(f in Fill,
          where: f.chain_type == :rollup and f.block_number >= ^from_block
        )
      )

    Logger.info(
      "Rollup reorg cleanup: deleted #{deleted_orders} orders, #{deleted_fills} fills from block #{from_block}"
    )
  end

  # Handle reorg on the host (L1) chain
  # This only affects host fills
  defp handle_host_reorg(from_block) do
    {deleted_fills, _} =
      Repo.delete_all(
        from(f in Fill,
          where: f.chain_type == :host and f.block_number >= ^from_block
        )
      )

    Logger.info("Host reorg cleanup: deleted #{deleted_fills} fills from block #{from_block}")
  end

  @doc """
  Check if a block is still valid in the chain by comparing its hash.

  Returns true if the block is still valid, false if it has been reorganized.
  """
  @spec block_still_valid?(non_neg_integer(), binary(), keyword()) :: boolean()
  def block_still_valid?(block_number, expected_hash, json_rpc_named_arguments) do
    request = %{
      id: 1,
      jsonrpc: "2.0",
      method: "eth_getBlockByNumber",
      params: ["0x#{Integer.to_string(block_number, 16)}", false]
    }

    case EthereumJSONRPC.json_rpc(request, json_rpc_named_arguments) do
      {:ok, block} when not is_nil(block) ->
        actual_hash = Map.get(block, "hash")
        normalize_hash(actual_hash) == normalize_hash(expected_hash)

      _ ->
        false
    end
  end

  defp normalize_hash("0x" <> hex), do: String.downcase(hex)
  defp normalize_hash(hex) when is_binary(hex), do: String.downcase(hex)
  defp normalize_hash(_), do: nil
end
