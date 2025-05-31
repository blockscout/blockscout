defmodule Indexer.Fetcher.Celo.EpochBlockOperations.ValidatorAndGroupPaymentsPostL2Migration do
  @moduledoc """
  Fetches validator and group payments for the epoch post L2 migration.
  """
  require Logger

  use Utils.RuntimeEnvHelper,
    epoch_manager_contract_address_hash: [
      :explorer,
      [:celo, :epoch_manager_contract_address]
    ],
    validators_contract_address_hash: [
      :explorer,
      [:celo, :validators_contract_address]
    ],
    json_rpc_named_arguments: [:indexer, :json_rpc_named_arguments]

  import Indexer.Helper,
    only: [
      read_contracts_with_retries_by_chunks: 3,
      read_contracts_with_retries: 4
    ]

  import Ecto.Query, only: [from: 2]
  import Explorer.Helper, only: [abi_to_method_id: 1]

  alias Explorer.Chain.{Block, Log}
  alias Explorer.Chain.Celo.Epoch
  alias Explorer.Repo

  @repeated_request_max_retries 3
  @requests_chunk_size 100

  @number_of_elected_in_current_set_abi [
    %{
      "name" => "numberOfElectedInCurrentSet",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [],
      "outputs" => [%{"type" => "uint256"}]
    }
  ]

  @get_elected_account_by_index_abi [
    %{
      "name" => "getElectedAccountByIndex",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"type" => "uint256"}],
      "outputs" => [%{"type" => "address"}]
    }
  ]

  @validator_pending_payments_abi [
    %{
      "name" => "validatorPendingPayments",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"type" => "address"}],
      "outputs" => [%{"type" => "uint256"}]
    }
  ]

  @get_validators_group_abi [
    %{
      "name" => "getValidatorsGroup",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"type" => "address"}],
      "outputs" => [%{"type" => "address"}]
    }
  ]

  @get_validator_group_abi [
    %{
      "name" => "getValidatorGroup",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"type" => "address"}],
      "outputs" => [
        %{"type" => "address[]"},
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256[]"},
        %{"type" => "uint256"},
        %{"type" => "uint256"}
      ]
    }
  ]

  @validator_epoch_payment_distributed_event_topic "0xee2788e7abedfc61d9608e143b172de1a608a4298b06ed8c84838aa0ad6bd136"

  def fetch(%Epoch{number: epoch_number, start_processing_block: %Block{number: block_number, hash: block_hash}}) do
    with false <-
           check_if_validator_payment_distributed_events_exist(block_hash),
         {:ok, length} <- number_of_elected_in_current_set(block_number),
         {:ok, account_address_hashes} <- get_elected_accounts(block_number, length),
         {:ok, payments_before} <- get_allocated_payments(account_address_hashes, block_number - 1),
         {:ok, payments_after} <- get_allocated_payments(account_address_hashes, block_number),
         {:ok, group_address_hashes} <- get_validator_groups(account_address_hashes, block_number),
         unique_group_address_hashes = Enum.uniq(group_address_hashes),
         {:ok, group_commissions} <- get_validator_group_commissions(unique_group_address_hashes, block_number) do
      account_address_hash_to_group_address_hash =
        account_address_hashes
        |> Enum.zip(group_address_hashes)
        |> Map.new()

      group_address_hash_to_commission =
        unique_group_address_hashes
        |> Enum.zip(group_commissions)
        |> Map.new()

      payments = Enum.zip_with(payments_after, payments_before, &(&1 - &2))

      params =
        account_address_hashes
        |> Enum.zip(payments)
        |> Enum.flat_map(fn {account_address_hash, payment} ->
          group_address_hash = Map.get(account_address_hash_to_group_address_hash, account_address_hash)

          base = Decimal.new(1, 1, 24)

          commission =
            group_address_hash_to_commission
            |> Map.get(group_address_hash)
            |> Decimal.new()
            |> Decimal.div(base)

          payment = payment |> Decimal.new()
          group_payment = payment |> Decimal.mult(commission)
          validator_payment = payment |> Decimal.sub(group_payment)

          [
            %{
              epoch_number: epoch_number,
              account_address_hash: account_address_hash,
              amount: validator_payment,
              associated_account_address_hash: group_address_hash,
              type: :validator
            },
            %{
              epoch_number: epoch_number,
              account_address_hash: group_address_hash,
              amount: group_payment,
              associated_account_address_hash: account_address_hash,
              type: :group
            }
          ]
        end)

      {:ok, params}
    else
      true ->
        # TODO: As invariant, we assume that the validator payment distributed
        # event is not present in the block. If it is present, this is a corner
        # case that should be addressed in the future.
        Logger.error("Validator payment distributed event exists for block hash: #{block_hash}. Aborting.")
        {:error, "Validator payment distributed event exists"}

      {:error, reason} ->
        Logger.error("Failed to fetch validator and group payments: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec number_of_elected_in_current_set(EthereumJSONRPC.block_number()) ::
          {:ok, integer()} | {:error, any()}
  defp number_of_elected_in_current_set(block_number) do
    method_id = @number_of_elected_in_current_set_abi |> abi_to_method_id()

    [
      %{
        contract_address: epoch_manager_contract_address_hash(),
        method_id: method_id,
        args: [],
        block_number: block_number
      }
    ]
    |> read_contracts_with_retries(
      @number_of_elected_in_current_set_abi,
      json_rpc_named_arguments(),
      @repeated_request_max_retries
    )
    |> case do
      {[ok: [value]], []} ->
        {:ok, value}

      {_, errors} ->
        {:error, errors}
    end
  end

  defp get_elected_accounts(block_number, length) when length > 0 do
    method_id = @get_elected_account_by_index_abi |> abi_to_method_id()

    0..(length - 1)
    |> Enum.map(fn index ->
      %{
        contract_address: epoch_manager_contract_address_hash(),
        method_id: method_id,
        args: [index],
        block_number: block_number
      }
    end)
    |> read_contract(@get_elected_account_by_index_abi)
    |> case do
      {responses, []} ->
        address_hashes =
          responses
          |> Enum.map(fn {:ok, [address_hash]} -> address_hash end)

        {:ok, address_hashes}

      {_, errors} ->
        {:error, errors}
    end
  end

  defp get_allocated_payments(account_address_hashes, block_number) do
    method_id = @validator_pending_payments_abi |> abi_to_method_id()

    account_address_hashes
    |> Enum.map(fn address_hash ->
      %{
        contract_address: epoch_manager_contract_address_hash(),
        method_id: method_id,
        args: [address_hash],
        block_number: block_number
      }
    end)
    |> read_contract(@validator_pending_payments_abi)
    |> case do
      {responses, []} ->
        values =
          responses
          |> Enum.map(fn {:ok, [value]} -> value end)

        {:ok, values}

      {_, errors} ->
        {:error, errors}
    end
  end

  defp get_validator_groups(account_address_hashes, block_number) do
    method_id = @get_validators_group_abi |> abi_to_method_id()

    account_address_hashes
    |> Enum.map(fn address_hash ->
      %{
        contract_address: validators_contract_address_hash(),
        method_id: method_id,
        args: [address_hash],
        block_number: block_number
      }
    end)
    |> read_contract(@get_validators_group_abi)
    |> case do
      {responses, []} ->
        values =
          responses
          |> Enum.map(fn {:ok, [value]} -> value end)

        {:ok, values}

      {_, errors} ->
        {:error, errors}
    end
  end

  defp get_validator_group_commissions(unique_group_address_hashes, block_number) do
    method_id = @get_validator_group_abi |> abi_to_method_id()

    unique_group_address_hashes
    |> Enum.map(fn address_hash ->
      %{
        contract_address: validators_contract_address_hash(),
        method_id: method_id,
        args: [address_hash],
        block_number: block_number
      }
    end)
    |> read_contract(@get_validator_group_abi)
    |> case do
      {responses, []} ->
        values =
          responses
          |> Enum.map(fn {:ok, [_, value | _]} -> value end)

        {:ok, values}

      {_, errors} ->
        {:error, errors}
    end
  end

  defp read_contract(requests, abi) do
    read_contracts_with_retries_by_chunks(
      requests,
      @requests_chunk_size,
      fn chunk ->
        read_contracts_with_retries(
          chunk,
          abi,
          json_rpc_named_arguments(),
          @repeated_request_max_retries
        )
      end
    )
  end

  defp check_if_validator_payment_distributed_events_exist(block_hash) do
    query =
      from(
        log in Log,
        where: [
          block_hash: ^block_hash,
          address_hash: ^epoch_manager_contract_address_hash(),
          first_topic: ^@validator_epoch_payment_distributed_event_topic
        ]
      )

    query
    |> Repo.exists?()
  end
end
