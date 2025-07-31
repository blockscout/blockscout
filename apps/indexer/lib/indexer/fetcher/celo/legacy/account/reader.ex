defmodule Indexer.Fetcher.Celo.Legacy.Account.Reader do
  @moduledoc false

  use Utils.RuntimeEnvHelper,
    accounts_contract_address_hash: [:explorer, [:celo, :accounts_contract_address]],
    locked_gold_contract_address_hash: [:explorer, [:celo, :locked_gold_contract_address]],
    validators_contract_address_hash: [:explorer, [:celo, :validators_contract_address]],
    json_rpc_named_arguments: [:indexer, :json_rpc_named_arguments]

  import Explorer.Helper, only: [abi_to_method_id: 1]
  import Indexer.Helper, only: [read_contracts_with_retries: 4]

  @repeated_request_max_retries 3

  @abi %{
    accounts: %{
      get_name: %{
        "constant" => true,
        "inputs" => [
          %{"internalType" => "address", "name" => "account", "type" => "address"}
        ],
        "name" => "getName",
        "outputs" => [
          %{"internalType" => "string", "name" => "", "type" => "string"}
        ],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      },
      get_metadata_url: %{
        "constant" => true,
        "inputs" => [
          %{"internalType" => "address", "name" => "account", "type" => "address"}
        ],
        "name" => "getMetadataURL",
        "outputs" => [
          %{"internalType" => "string", "name" => "", "type" => "string"}
        ],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      }
    },
    locked_gold: %{
      get_account_total_locked_gold: %{
        "constant" => true,
        "inputs" => [
          %{"internalType" => "address", "name" => "account", "type" => "address"}
        ],
        "name" => "getAccountTotalLockedGold",
        "outputs" => [
          %{"internalType" => "uint256", "name" => "", "type" => "uint256"}
        ],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      },
      get_account_nonvoting_locked_gold: %{
        "constant" => true,
        "inputs" => [
          %{"internalType" => "address", "name" => "account", "type" => "address"}
        ],
        "name" => "getAccountNonvotingLockedGold",
        "outputs" => [
          %{"internalType" => "uint256", "name" => "", "type" => "uint256"}
        ],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      }
    },
    validators: %{
      is_validator: %{
        "constant" => true,
        "inputs" => [%{"name" => "_someone", "type" => "address"}],
        "name" => "isValidator",
        "outputs" => [%{"name" => "", "type" => "bool"}],
        "payable" => false,
        "signature" => "0xfacd743b",
        "stateMutability" => "view",
        "type" => "function"
      },
      is_validator_group: %{
        "constant" => true,
        "inputs" => [
          %{"internalType" => "address", "name" => "account", "type" => "address"}
        ],
        "name" => "isValidatorGroup",
        "outputs" => [%{"internalType" => "bool", "name" => "", "type" => "bool"}],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      }
    }
  }

  @doc """
  Read Celo account data from core smart contracts.
  """
  @spec fetch(String.t()) :: {:ok, map()} | :error
  def fetch(account_address) do
    dbg(account_address)
    with {:ok, data} <- do_fetch(account_address),
         {:ok, [name]} <- data.get_name,
         {:ok, [url]} <- data.get_metadata_url,
         {:ok, [account_address]} <- data.get_name,
         {:ok, [locked_gold]} <- data.get_account_total_locked_gold,
         {:ok, [nonvoting_locked_gold]} <- data.get_account_nonvoting_locked_gold,
         {:ok, [is_validator]} <- data.is_validator,
         {:ok, [is_validator_group]} <- data.is_validator_group do
      type =
        cond do
          is_validator ->
            :validator

          is_validator_group ->
            :group

          true ->
            :regular
        end

      {
        :ok,
        %{
          address: account_address,
          name: name,
          url: url,
          locked_gold: locked_gold,
          nonvoting_locked_gold: nonvoting_locked_gold,
          type: type
        }
      }
    else
      _ ->
        :error
    end
  end

  @spec do_fetch(String.t()) :: {:ok, map()} | {:error, any()}
  defp do_fetch(account_address) do
    requests = [
      %{
        contract_address: accounts_contract_address_hash(),
        method_id: abi_to_method_id(@abi.accounts.get_name),
        args: [account_address],
        abi: @abi.accounts.get_name,
        name: :get_name
      },
      %{
        contract_address: accounts_contract_address_hash(),
        method_id: abi_to_method_id(@abi.accounts.get_metadata_url),
        args: [account_address],
        abi: @abi.accounts.get_metadata_url,
        name: :get_metadata_url
      },
      %{
        contract_address: locked_gold_contract_address_hash(),
        method_id: abi_to_method_id(@abi.locked_gold.get_account_total_locked_gold),
        args: [account_address],
        abi: @abi.locked_gold.get_account_total_locked_gold,
        name: :get_account_total_locked_gold
      },
      %{
        contract_address: locked_gold_contract_address_hash(),
        method_id: abi_to_method_id(@abi.locked_gold.get_account_nonvoting_locked_gold),
        args: [account_address],
        abi: @abi.locked_gold.get_account_nonvoting_locked_gold,
        name: :get_account_nonvoting_locked_gold
      },
      %{
        contract_address: validators_contract_address_hash(),
        method_id: abi_to_method_id(@abi.validators.is_validator),
        args: [account_address],
        abi: @abi.validators.is_validator,
        name: :is_validator
      },
      %{
        contract_address: validators_contract_address_hash(),
        method_id: abi_to_method_id(@abi.validators.is_validator_group),
        args: [account_address],
        abi: @abi.validators.is_validator_group,
        name: :is_validator_group
      }
    ]

    abis = Enum.map(requests, & &1.abi)

    read_contracts_with_retries(
      requests,
      abis,
      json_rpc_named_arguments(),
      @repeated_request_max_retries
    )
    |> case do
      {responses, []} ->
        data =
          Enum.zip(requests, responses)
          |> Enum.into(%{}, fn {request, response} -> {request.name, response} end)

        {:ok, data}

      {_responses, errors} ->
        {:error, errors}
    end
  end
end
