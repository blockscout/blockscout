defmodule EthereumJsonrpc.NFT do
  @moduledoc """
    Module responsible for requesting token_uri and uri methods which needed for NFT metadata fetching
  """

  @token_uri "c87b56dd"
  @base_uri "6c0360eb"
  @uri "0e89341c"

  @vm_execution_error "VM execution error"

  @erc_721_1155_abi [
    %{
      "inputs" => [],
      "name" => "baseURI",
      "outputs" => [
        %{
          "internalType" => "string",
          "name" => "",
          "type" => "string"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{"type" => "string", "name" => ""}
      ],
      "name" => "tokenURI",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_tokenId"
        }
      ],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{
          "type" => "string",
          "name" => "",
          "internalType" => "string"
        }
      ],
      "name" => "uri",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_id",
          "internalType" => "uint256"
        }
      ],
      "constant" => true
    }
  ]

  def batch_metadata_url_request(token_instances, json_rpc_named_arguments) do
    {mb_retry, other} =
      token_instances
      |> prepare_requests()
      |> EthereumJSONRPC.execute_contract_functions(@erc_721_1155_abi, json_rpc_named_arguments, false)
      |> cast_vm_execution_errors()
      |> Enum.with_index()
      |> Enum.split_with(fn
        {{:error, @vm_execution_error}, _ind} -> true
        _ -> false
      end)

    retry_result =
      if Application.get_env(:indexer, __MODULE__)[:base_uri_retry?] do
        {instances, indexes} =
          mb_retry
          |> Enum.map(fn {_, ind} ->
            {token_instances |> Enum.at(ind), ind}
          end)
          |> Enum.unzip()

        instances
        |> prepare_requests(true)
        |> EthereumJSONRPC.execute_contract_functions(@erc_721_1155_abi, json_rpc_named_arguments, false)
        |> cast_vm_execution_errors(true)
        |> Enum.zip(indexes)
      else
        mb_retry
      end

    (other ++ retry_result) |> Enum.sort_by(fn {_, ind} -> ind end) |> Enum.map(&elem(&1, 0))
  end

  defp cast_vm_execution_errors(results, from_base_uri? \\ false) do
    results
    |> Enum.map(fn
      {:error, error} ->
        error =
          if error =~ "execution reverted" or error =~ @vm_execution_error do
            @vm_execution_error
          else
            error
          end

        {{:error, error}, from_base_uri?}

      other ->
        {other, from_base_uri?}
    end)
  end

  defp prepare_requests(token_instances, from_base_uri? \\ false) do
    token_instances
    |> Enum.map(fn {token_contract_address_hash, token_id, token_type} ->
      token_id = prepare_token_id(token_id)
      token_contract_address_hash_string = to_string(token_contract_address_hash)

      prepare_request(
        token_type,
        token_contract_address_hash_string,
        token_id,
        from_base_uri?
      )
    end)
  end

  def prepare_request(token_type, contract_address_hash_string, token_id, from_base_uri?)
      when token_type in ["ERC-404", "ERC-721"] do
    request = %{
      contract_address: contract_address_hash_string,
      block_number: nil
    }

    if from_base_uri? do
      request |> Map.put(:method_id, @base_uri) |> Map.put(:args, [])
    else
      request |> Map.put(:method_id, @token_uri) |> Map.put(:args, [token_id])
    end
  end

  def prepare_request(_token_type, contract_address_hash_string, token_id, from_base_uri?) do
    request = %{
      contract_address: contract_address_hash_string,
      block_number: nil
    }

    if from_base_uri? do
      request |> Map.put(:method_id, @base_uri) |> Map.put(:args, [])
    else
      request |> Map.put(:method_id, @uri) |> Map.put(:args, [token_id])
    end
  end

  @doc """
  Prepares token id for request.
  """
  @spec prepare_token_id(any) :: any
  def prepare_token_id(%Decimal{} = token_id), do: Decimal.to_integer(token_id)
  def prepare_token_id(token_id), do: token_id

  @doc """
  Returns the ABI of uri, tokenURI, baseURI getters for ERC-721 and ERC-1155 tokens.
  """
  def erc_721_1155_abi do
    @erc_721_1155_abi
  end

  @doc """
  Returns tokenURI method signature.
  """
  def token_uri do
    @token_uri
  end
end
