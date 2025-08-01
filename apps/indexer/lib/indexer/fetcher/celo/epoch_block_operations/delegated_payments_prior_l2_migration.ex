defmodule Indexer.Fetcher.Celo.EpochBlockOperations.DelegatedPaymentsPriorL2Migration do
  @moduledoc """
  Fetches delegated validator payments for the epoch block.
  """
  import Ecto.Query, only: [from: 2]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Explorer.Helper, only: [abi_to_method_id: 1]

  import Indexer.Helper,
    only: [
      read_contracts_with_retries_by_chunks: 3,
      read_contracts_with_retries: 4
    ]

  alias Explorer.Chain.{Block, Hash, TokenTransfer}
  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Celo.Epoch
  alias Explorer.Chain.Wei
  alias Explorer.Repo
  alias Indexer.Fetcher.Celo.EpochBlockOperations.CoreContractVersion

  require Logger

  @mint_address_hash_string burn_address_hash_string()

  @repeated_request_max_retries 3
  @requests_chunk_size 100

  # The method `getPaymentDelegation` was introduced in the following. Thus, we
  # set version hardcoded in `getVersionNumber` method.
  #
  # https://github.com/celo-org/celo-monorepo/blob/d7c8936dc529f46d56799365f8b3383a23cc220b/packages/protocol/contracts/common/Accounts.sol#L128-L130
  @get_payment_delegation_available_since_version {1, 1, 3, 0}
  @get_payment_delegation_abi [
    %{
      "name" => "getPaymentDelegation",
      "type" => "function",
      "payable" => false,
      "constant" => true,
      "stateMutability" => "view",
      "inputs" => [
        %{"name" => "account", "type" => "address"}
      ],
      "outputs" => [
        %{"type" => "address"},
        %{"type" => "uint256"}
      ]
    }
  ]
  @get_payment_delegation_method_id @get_payment_delegation_abi |> abi_to_method_id()

  @spec fetch(
          [EthereumJSONRPC.address()],
          Epoch.t(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) ::
          {:ok, list()}
          | {:error, any()}
  def fetch(
        validator_addresses,
        %Epoch{start_processing_block: %Block{number: block_number, hash: block_hash}} = epoch,
        json_rpc_named_arguments
      ) do
    with {:ok, accounts_contract_address} <-
           CeloCoreContracts.get_address(:accounts, block_number),
         {:ok, accounts_contract_version} <-
           CoreContractVersion.fetch(
             accounts_contract_address,
             block_number,
             json_rpc_named_arguments
           ),
         true <- accounts_contract_version >= @get_payment_delegation_available_since_version,
         {:ok, usd_token_contract_address} <-
           CeloCoreContracts.get_address(:usd_token, block_number),
         {responses, []} <-
           read_payment_delegations(
             validator_addresses,
             accounts_contract_address,
             block_number,
             json_rpc_named_arguments
           ) do
      query =
        from(
          tt in TokenTransfer.only_consensus_transfers_query(),
          where:
            tt.block_hash == ^block_hash and
              tt.token_contract_address_hash == ^usd_token_contract_address and
              tt.from_address_hash == ^@mint_address_hash_string and
              is_nil(tt.transaction_hash),
          select: {tt.to_address_hash, tt.amount}
        )

      beneficiary_address_to_amount =
        query
        |> Repo.all()
        |> Map.new(fn {address, amount} ->
          {Hash.to_string(address), amount}
        end)

      rewards =
        validator_addresses
        |> Enum.zip(responses)
        |> Enum.filter(&match?({_, {:ok, [_, fraction]}} when fraction > 0, &1))
        |> Enum.map(fn
          {validator_address, {:ok, [beneficiary_address, _]}} ->
            amount = beneficiary_address_to_amount |> Map.get(beneficiary_address, 0)

            %{
              epoch_number: epoch.number,
              account_address_hash: beneficiary_address,
              amount: %Wei{value: amount},
              associated_account_address_hash: validator_address,
              type: :delegated_payment
            }
        end)

      {:ok, rewards}
    else
      false ->
        Logger.info(fn ->
          [
            "Do not fetch payment delegations since `getPaymentDelegation` ",
            "method is not available on block #{block_number}"
          ]
        end)

        {:ok, []}

      {_, ["(-32000) execution reverted"]} ->
        # todo: we should start fetching payment delegations only after the
        # first `PaymentDelegationSet` event is emitted. Unfortunately, relying
        # on contract version is not enough since the method could not be
        # present.
        Logger.info(fn ->
          [
            "Could not fetch payment delegations since `getPaymentDelegation` constantly returns error. ",
            "Most likely, the method is not available on block #{block_number}. "
          ]
        end)

        {:ok, []}

      error ->
        Logger.error("Could not fetch payment delegations: #{inspect(error)}")

        error
    end
  end

  defp read_payment_delegations(
         validator_addresses,
         accounts_contract_address,
         block_number,
         json_rpc_named_arguments
       ) do
    validator_addresses
    |> Enum.map(
      &%{
        contract_address: accounts_contract_address,
        method_id: @get_payment_delegation_method_id,
        args: [&1],
        block_number: block_number
      }
    )
    |> read_contracts_with_retries_by_chunks(
      @requests_chunk_size,
      fn requests ->
        read_contracts_with_retries(
          requests,
          @get_payment_delegation_abi,
          json_rpc_named_arguments,
          @repeated_request_max_retries
        )
      end
    )
  end
end
