# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Fetcher.ContractCreationBlock do
  @moduledoc """
  Finds the block in which a contract was created using a binary search over
  `eth_getTransactionCount` (the contract nonce is `0` before creation and
  `>= 1` from the creation block on, since EIP-161).

  The search only relies on the JSON RPC node, so it works for contracts whose
  creation is not (yet) indexed. Callers must validate the result: for
  contracts with a nonce of `0` at every block (pre-Spurious-Dragon contracts,
  some predeploys) the search converges on the right bound.
  """

  require Logger

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2]

  alias EthereumJSONRPC.Nonce
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Hash

  @default_max_retries 5
  @default_retry_delay_ms 1_000

  @doc """
  Finds the creation block number of the contract at `address_hash`.

  ## Options

    * `:max_block_number` - right bound of the search (default: `Explorer.Chain.Cache.BlockNumber.get_max/0`).
    * `:max_retries` - number of retries after a JSON RPC error (default: `#{@default_max_retries}`).
    * `:retry_delay_ms` - pause between retries (default: `#{@default_retry_delay_ms}`).
    * `:json_rpc_named_arguments` - JSON RPC connection (default: `Application.get_env(:explorer, :json_rpc_named_arguments)`).
  """
  @spec find(Hash.Address.t() | binary(), keyword()) :: {:ok, non_neg_integer()} | {:error, :max_retries}
  def find(address_hash, opts \\ []) do
    max_block_number = Keyword.get_lazy(opts, :max_block_number, fn -> BlockNumber.get_max() end)

    context = %{
      address: to_string(address_hash),
      retry_delay_ms: Keyword.get(opts, :retry_delay_ms, @default_retry_delay_ms),
      json_rpc_named_arguments:
        Keyword.get_lazy(opts, :json_rpc_named_arguments, fn ->
          Application.get_env(:explorer, :json_rpc_named_arguments)
        end)
    }

    block_ranges = %{left: 0, right: max_block_number, previous_nonce: nil}

    search(block_ranges, context, Keyword.get(opts, :max_retries, @default_max_retries))
  end

  # A singleton range needs no request: the only candidate is the block itself
  # (which is also the right bound, validated by the caller).
  defp search(%{left: block_number, right: block_number}, _context, _retries_left), do: {:ok, block_number}

  defp search(block_ranges, context, retries_left) do
    medium = trunc((block_ranges.right - block_ranges.left) / 2)
    medium_position = block_ranges.left + medium

    params = %{block_quantity: integer_to_quantity(medium_position), address: context.address}
    id_to_params = id_to_params([params])

    case params
         |> Map.merge(%{id: 0})
         |> Nonce.request()
         |> json_rpc(context.json_rpc_named_arguments) do
      {:ok, response} ->
        case Nonce.from_response(%{id: 0, result: response}, id_to_params) do
          {:ok, %{nonce: 0}} ->
            block_ranges
            |> Map.put(:left, new_left_position(medium, medium_position))
            |> maybe_continue(context, 0, retries_left)

          {:ok, %{nonce: nonce}} when nonce > 0 ->
            # a positive nonce means the contract exists at `medium_position`, so the
            # block stays a candidate; moving the bound below it would invert the range
            block_ranges
            |> Map.put(:right, medium_position)
            |> maybe_continue(context, nonce, retries_left)

          _ ->
            Logger.error("Error while fetching 'eth_getTransactionCount' for address #{context.address}")
            retry(block_ranges, context, retries_left)
        end

      {:error, reason} ->
        Logger.error(
          "Error while fetching 'eth_getTransactionCount' for address #{context.address}: #{inspect(reason)}"
        )

        retry(block_ranges, context, retries_left)
    end
  end

  defp retry(_block_ranges, context, 0) do
    Logger.error("Reached max retry attempts for 'eth_getTransactionCount' for address #{context.address}")

    {:error, :max_retries}
  end

  defp retry(block_ranges, context, retries_left) do
    :timer.sleep(context.retry_delay_ms)
    search(block_ranges, context, retries_left - 1)
  end

  defp new_left_position(medium, medium_position) do
    if medium == 0, do: medium_position + 1, else: medium_position
  end

  defp maybe_continue(block_ranges, context, nonce, retries_left) do
    cond do
      block_ranges.left == block_ranges.right ->
        {:ok, block_ranges.left}

      block_ranges.right - block_ranges.left == 1 && nonce !== block_ranges.previous_nonce ->
        {:ok, block_ranges.right}

      true ->
        block_ranges
        |> Map.put(:previous_nonce, nonce)
        |> search(context, retries_left)
    end
  end
end
