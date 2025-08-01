defmodule Explorer.TokenInstanceOwnerAddressMigration.Helper do
  @moduledoc """
    Auxiliary functions for TokenInstanceOwnerAddressMigration.{Worker and Supervisor}
  """
  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Token.Instance
  alias Explorer.Chain.{SmartContract, TokenTransfer}

  require Logger

  {:ok, burn_address_hash} = Chain.string_to_address_hash(SmartContract.burn_address_hash_string())
  @burn_address_hash burn_address_hash

  @spec filtered_token_instances_query(non_neg_integer()) :: Ecto.Query.t()
  def filtered_token_instances_query(limit) do
    from(instance in Instance,
      where: is_nil(instance.owner_address_hash),
      inner_join: token in assoc(instance, :token),
      where: token.type == "ERC-721",
      limit: ^limit,
      select: %{token_id: instance.token_id, token_contract_address_hash: instance.token_contract_address_hash}
    )
  end

  @spec fetch_and_insert([map]) ::
          {:error, :timeout | [map]}
          | {:ok,
             %{
               :token_instances => [Instance.t()]
             }}
          | {:error, any, any, map}
  def fetch_and_insert(batch) do
    changes =
      batch
      |> Enum.map(&process_instance/1)
      |> Enum.reject(&is_nil/1)

    Chain.import(%{token_instances: %{params: changes}})
  end

  defp process_instance(%{token_id: token_id, token_contract_address_hash: token_contract_address_hash}) do
    token_transfer_query =
      from(tt in TokenTransfer.only_consensus_transfers_query(),
        where:
          tt.token_contract_address_hash == ^token_contract_address_hash and
            fragment("? @> ARRAY[?::decimal]", tt.token_ids, ^token_id),
        order_by: [desc: tt.block_number, desc: tt.log_index],
        limit: 1,
        select: %{
          token_contract_address_hash: tt.token_contract_address_hash,
          token_ids: tt.token_ids,
          to_address_hash: tt.to_address_hash,
          block_number: tt.block_number,
          log_index: tt.log_index
        }
      )

    token_transfer =
      Repo.one(token_transfer_query, timeout: :timer.minutes(5)) ||
        %{to_address_hash: @burn_address_hash, block_number: -1, log_index: -1}

    %{
      token_contract_address_hash: token_contract_address_hash,
      token_id: token_id,
      token_type: "ERC-721",
      owner_address_hash: token_transfer.to_address_hash,
      owner_updated_at_block: token_transfer.block_number,
      owner_updated_at_log_index: token_transfer.log_index
    }
  rescue
    exception in DBConnection.ConnectionError ->
      Logger.warning(fn ->
        [
          "Error deriving owner address hash for {#{to_string(token_contract_address_hash)}, #{to_string(token_id)}}: ",
          Exception.format(:error, exception, __STACKTRACE__)
        ]
      end)

      nil
  end

  @spec unfilled_token_instances_exists? :: boolean
  def unfilled_token_instances_exists? do
    1
    |> filtered_token_instances_query()
    |> Repo.exists?()
  end
end
