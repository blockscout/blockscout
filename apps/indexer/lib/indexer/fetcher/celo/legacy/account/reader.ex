defmodule Indexer.Fetcher.Celo.Legacy.Account.Reader do
  @moduledoc """
  Reads Celo account data from core smart contracts.

  This module provides functionality to fetch account information including
  name, metadata URL, locked gold amounts, and validator status from the
  Celo blockchain's core contracts.
  """
  require Logger

  use Utils.RuntimeEnvHelper,
    accounts_contract_address_hash: [:explorer, [:celo, :accounts_contract_address]],
    locked_gold_contract_address_hash: [:explorer, [:celo, :locked_gold_contract_address]],
    validators_contract_address_hash: [:explorer, [:celo, :validators_contract_address]],
    json_rpc_named_arguments: [:indexer, :json_rpc_named_arguments]

  import Explorer.Helper, only: [abi_to_method_id: 1]

  import Indexer.Helper,
    only: [read_contracts_with_retries: 4]

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
      },
      get_vote_signer: %{
        "constant" => true,
        "inputs" => [%{"name" => "account", "type" => "address"}],
        "name" => "getVoteSigner",
        "outputs" => [%{"name" => "", "type" => "address"}],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      },
      get_validator_signer: %{
        "constant" => true,
        "inputs" => [%{"name" => "account", "type" => "address"}],
        "name" => "getValidatorSigner",
        "outputs" => [%{"name" => "", "type" => "address"}],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      },
      get_attestation_signer: %{
        "constant" => true,
        "inputs" => [%{"name" => "account", "type" => "address"}],
        "name" => "getAttestationSigner",
        "outputs" => [%{"name" => "", "type" => "address"}],
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

  @abis @abi |> Map.values() |> Enum.flat_map(&Map.values/1)

  @doc """
  Read Celo account data from core smart contracts.
  """
  @spec fetch(String.t()) :: {:ok, map()} | :error
  def fetch(account_address) do
    account_address
    |> do_fetch()
    |> case do
      {:ok,
       [
         {:ok, [name]},
         {:ok, [url]},
         {:ok, [locked_gold]},
         {:ok, [nonvoting_locked_gold]},
         {:ok, [is_validator]},
         {:ok, [is_validator_group]},
         {:ok, [vote_signer]},
         {:ok, [validator_signer]},
         {:ok, [attestation_signer]}
       ]} ->
        type =
          cond do
            is_validator ->
              :validator

            is_validator_group ->
              :group

            true ->
              :regular
          end

        {:ok,
         %{
           address_hash: account_address,
           name: truncate(name),
           metadata_url: truncate(url),
           locked_celo: locked_gold,
           nonvoting_locked_celo: nonvoting_locked_gold,
           type: type,
           vote_signer_address_hash: normalize_signer(account_address, vote_signer),
           validator_signer_address_hash: normalize_signer(account_address, validator_signer),
           attestation_signer_address_hash: normalize_signer(account_address, attestation_signer)
         }}

      {:error, errors} ->
        Logger.error(fn ->
          ["Failed to fetch Celo account data for ", account_address, ": ", inspect(errors)]
        end)

        :error
    end
  end

  @spec truncate(binary()) :: binary()
  defp truncate(binary) when is_binary(binary) do
    String.slice(binary, 0, 255)
  end

  @spec normalize_signer(String.t(), String.t()) :: String.t() | nil
  defp normalize_signer(address_hash, signer_address_hash) do
    if address_hash == signer_address_hash do
      nil
    else
      signer_address_hash
    end
  end

  @spec do_fetch(String.t()) :: {:ok, keyword()} | {:error, any()}
  defp do_fetch(account_address) do
    requests = [
      %{
        contract_address: accounts_contract_address_hash(),
        method_id: abi_to_method_id(@abi.accounts.get_name),
        args: [account_address]
      },
      %{
        contract_address: accounts_contract_address_hash(),
        method_id: abi_to_method_id(@abi.accounts.get_metadata_url),
        args: [account_address]
      },
      %{
        contract_address: locked_gold_contract_address_hash(),
        method_id: abi_to_method_id(@abi.locked_gold.get_account_total_locked_gold),
        args: [account_address]
      },
      %{
        contract_address: locked_gold_contract_address_hash(),
        method_id: abi_to_method_id(@abi.locked_gold.get_account_nonvoting_locked_gold),
        args: [account_address]
      },
      %{
        contract_address: validators_contract_address_hash(),
        method_id: abi_to_method_id(@abi.validators.is_validator),
        args: [account_address]
      },
      %{
        contract_address: validators_contract_address_hash(),
        method_id: abi_to_method_id(@abi.validators.is_validator_group),
        args: [account_address]
      },
      %{
        contract_address: accounts_contract_address_hash(),
        method_id: abi_to_method_id(@abi.accounts.get_vote_signer),
        args: [account_address]
      },
      %{
        contract_address: accounts_contract_address_hash(),
        method_id: abi_to_method_id(@abi.accounts.get_validator_signer),
        args: [account_address]
      },
      %{
        contract_address: accounts_contract_address_hash(),
        method_id: abi_to_method_id(@abi.accounts.get_attestation_signer),
        args: [account_address]
      }
    ]

    requests
    |> read_contracts_with_retries(
      @abis,
      json_rpc_named_arguments(),
      @repeated_request_max_retries
    )
    |> case do
      {responses, []} ->
        {:ok, responses}

      {_responses, errors} ->
        {:error, errors}
    end
  end
end
