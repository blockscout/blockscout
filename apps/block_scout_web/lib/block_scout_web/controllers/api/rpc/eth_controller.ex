defmodule BlockScoutWeb.API.RPC.EthController do
  use BlockScoutWeb, :controller

  alias Ecto.Type, as: EctoType
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Data, Hash, Hash.Address, Wei}
  alias Explorer.Etherscan.Logs

  @methods %{
    "eth_getBalance" => %{
      action: :eth_get_balance,
      notes: """
      the `earliest` parameter will not work as expected currently, because genesis block balances
      are not currently imported
      """
    },
    "eth_getLogs" => %{
      action: :eth_get_logs,
      notes: """
      Will never return more than 1000 log entries.
      """
    }
  }

  @index_to_word %{
    0 => "first",
    1 => "second",
    2 => "third",
    3 => "fourth"
  }

  def methods, do: @methods

  def eth_request(%{body_params: %{"_json" => requests}} = conn, _) when is_list(requests) do
    responses = responses(requests)

    conn
    |> put_status(200)
    |> render("responses.json", %{responses: responses})
  end

  def eth_request(%{body_params: %{"_json" => request}} = conn, _) do
    [response] = responses([request])

    conn
    |> put_status(200)
    |> render("response.json", %{response: response})
  end

  def eth_request(conn, request) do
    # In the case that the JSON body is sent up w/o a json content type,
    # Phoenix encodes it as a single key value pair, with the value being
    # nil and the body being the key (as in a CURL request w/ no content type header)
    decoded_request =
      with [{single_key, nil}] <- Map.to_list(request),
           {:ok, decoded} <- Jason.decode(single_key) do
        decoded
      else
        _ -> request
      end

    [response] = responses([decoded_request])

    conn
    |> put_status(200)
    |> render("response.json", %{response: response})
  end

  def eth_get_balance(address_param, block_param \\ nil) do
    with {:address, {:ok, address}} <- {:address, Chain.string_to_address_hash(address_param)},
         {:block, {:ok, block}} <- {:block, block_param(block_param)},
         {:balance, {:ok, balance}} <- {:balance, Chain.get_balance_as_of_block(address, block)} do
      {:ok, Wei.hex_format(balance)}
    else
      {:address, :error} ->
        {:error, "Query parameter 'address' is invalid"}

      {:block, :error} ->
        {:error, "Query parameter 'block' is invalid"}

      {:balance, {:error, :not_found}} ->
        {:error, "Balance not found"}
    end
  end

  def eth_get_logs(filter_options) do
    with {:ok, address_or_topic_params} <- address_or_topic_params(filter_options),
         {:ok, from_block_param, to_block_param} <- logs_blocks_filter(filter_options),
         {:ok, from_block} <- cast_block(from_block_param),
         {:ok, to_block} <- cast_block(to_block_param) do
      filter =
        address_or_topic_params
        |> Map.put(:from_block, from_block)
        |> Map.put(:to_block, to_block)
        |> Map.put(:allow_non_consensus, true)

      {:ok, filter |> Logs.list_logs() |> Enum.map(&render_log/1)}
    else
      {:error, message} when is_bitstring(message) ->
        {:error, message}

      {:error, :empty} ->
        {:ok, []}

      _ ->
        {:error, "Something went wrong."}
    end
  end

  defp render_log(log) do
    topics =
      Enum.reject(
        [log.first_topic, log.second_topic, log.third_topic, log.fourth_topic],
        &is_nil/1
      )

    %{
      "address" => to_string(log.address_hash),
      "blockHash" => to_string(log.block_hash),
      "blockNumber" => Integer.to_string(log.block_number, 16),
      "data" => to_string(log.data),
      "logIndex" => Integer.to_string(log.index, 16),
      "removed" => log.block_consensus == false,
      "topics" => topics,
      "transactionHash" => to_string(log.transaction_hash),
      "transactionIndex" => log.transaction_index,
      "transactionLogIndex" => log.index,
      "type" => "mined"
    }
  end

  defp cast_block("0x" <> hexadecimal_digits = input) do
    case Integer.parse(hexadecimal_digits, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, input <> " is not a valid block number"}
    end
  end

  defp cast_block(integer) when is_integer(integer), do: {:ok, integer}
  defp cast_block(_), do: {:error, "invalid block number"}

  defp address_or_topic_params(filter_options) do
    address_param = Map.get(filter_options, "address")
    topics_param = Map.get(filter_options, "topics")

    with {:ok, address} <- validate_address(address_param),
         {:ok, topics} <- validate_topics(topics_param) do
      address_and_topics(address, topics)
    end
  end

  defp address_and_topics(nil, nil), do: {:error, "Must supply one of address and topics"}
  defp address_and_topics(address, nil), do: {:ok, %{address_hash: address}}
  defp address_and_topics(nil, topics), do: {:ok, topics}
  defp address_and_topics(address, topics), do: {:ok, Map.put(topics, :address_hash, address)}

  defp validate_address(nil), do: {:ok, nil}

  defp validate_address(address) do
    case Address.cast(address) do
      {:ok, address} -> {:ok, address}
      :error -> {:error, "invalid address"}
    end
  end

  defp validate_topics(nil), do: {:ok, nil}
  defp validate_topics([]), do: []

  defp validate_topics(topics) when is_list(topics) do
    topics
    |> Stream.with_index()
    |> Enum.reduce({:ok, %{}}, fn {topic, index}, {:ok, acc} ->
      case cast_topics(topic) do
        {:ok, data} ->
          with_filter = Map.put(acc, String.to_existing_atom("#{@index_to_word[index]}_topic"), data)

          {:ok, add_operator(with_filter, index)}

        :error ->
          {:error, "invalid topics"}
      end
    end)
  end

  defp add_operator(filters, 0), do: filters

  defp add_operator(filters, index) do
    Map.put(filters, String.to_existing_atom("topic#{index - 1}_#{index}_opr"), "and")
  end

  defp cast_topics(topics) when is_list(topics) do
    case EctoType.cast({:array, Data}, topics) do
      {:ok, data} -> {:ok, Enum.map(data, &to_string/1)}
      :error -> :error
    end
  end

  defp cast_topics(topic) do
    case Data.cast(topic) do
      {:ok, data} -> {:ok, to_string(data)}
      :error -> :error
    end
  end

  defp responses(requests) do
    Enum.map(requests, fn request ->
      with {:id, {:ok, id}} <- {:id, Map.fetch(request, "id")},
           {:request, {:ok, result}} <- {:request, do_eth_request(request)} do
        format_success(result, id)
      else
        {:id, :error} -> format_error("id is a required field", 0)
        {:request, {:error, message}} -> format_error(message, Map.get(request, "id"))
      end
    end)
  end

  defp logs_blocks_filter(filter_options) do
    with {:filter, %{"blockHash" => block_hash_param}} <- {:filter, filter_options},
         {:block_hash, {:ok, block_hash}} <- {:block_hash, Hash.Full.cast(block_hash_param)},
         {:block, %{number: number}} <- {:block, Repo.get(Block, block_hash)} do
      {:ok, number, number}
    else
      {:filter, filters} ->
        from_block = Map.get(filters, "fromBlock", "latest")
        to_block = Map.get(filters, "toBlock", "latest")

        max_block_number =
          if from_block == "latest" || to_block == "latest" do
            max_consensus_block_number()
          end

        pending_block_number =
          if from_block == "pending" || to_block == "pending" do
            max_non_consensus_block_number(max_block_number)
          end

        if is_nil(pending_block_number) && from_block == "pending" && to_block == "pending" do
          {:error, :empty}
        else
          to_block_numbers(from_block, to_block, max_block_number, pending_block_number)
        end

      {:block, _} ->
        {:error, "Invalid Block Hash"}

      {:block_hash, _} ->
        {:error, "Invalid Block Hash"}
    end
  end

  defp to_block_numbers(from_block, to_block, max_block_number, pending_block_number) do
    actual_pending_block_number = pending_block_number || max_block_number

    with {:ok, from} <-
           to_block_number(from_block, max_block_number, actual_pending_block_number),
         {:ok, to} <- to_block_number(to_block, max_block_number, actual_pending_block_number) do
      {:ok, from, to}
    end
  end

  defp to_block_number(integer, _, _) when is_integer(integer), do: {:ok, integer}
  defp to_block_number("latest", max_block_number, _), do: {:ok, max_block_number || 0}
  defp to_block_number("earliest", _, _), do: {:ok, 0}
  defp to_block_number("pending", max_block_number, nil), do: {:ok, max_block_number || 0}
  defp to_block_number("pending", _, pending), do: {:ok, pending}

  defp to_block_number("0x" <> number, _, _) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "invalid block number"}
    end
  end

  defp to_block_number(number, _, _) when is_bitstring(number) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "invalid block number"}
    end
  end

  defp to_block_number(_, _, _), do: {:error, "invalid block number"}

  defp max_non_consensus_block_number(max) do
    case Chain.max_non_consensus_block_number(max) do
      {:ok, number} -> number
      _ -> nil
    end
  end

  defp max_consensus_block_number do
    case Chain.max_consensus_block_number() do
      {:ok, number} -> number
      _ -> nil
    end
  end

  defp format_success(result, id) do
    %{result: result, id: id}
  end

  defp format_error(message, id) do
    %{error: message, id: id}
  end

  defp do_eth_request(%{"jsonrpc" => rpc_version}) when rpc_version != "2.0" do
    {:error, "invalid rpc version"}
  end

  defp do_eth_request(%{"jsonrpc" => "2.0", "method" => method, "params" => params})
       when is_list(params) do
    with {:ok, action} <- get_action(method),
         {:correct_arity, true} <-
           {:correct_arity, :erlang.function_exported(__MODULE__, action, Enum.count(params))} do
      apply(__MODULE__, action, params)
    else
      {:correct_arity, _} ->
        {:error, "Incorrect number of params."}

      _ ->
        {:error, "Action not found."}
    end
  end

  defp do_eth_request(%{"params" => _params, "method" => _}) do
    {:error, "Invalid params. Params must be a list."}
  end

  defp do_eth_request(_) do
    {:error, "Method, params, and jsonrpc, are all required parameters."}
  end

  defp get_action(action) do
    case Map.get(@methods, action) do
      %{action: action} ->
        {:ok, action}

      _ ->
        :error
    end
  end

  defp block_param("latest"), do: {:ok, :latest}
  defp block_param("earliest"), do: {:ok, :earliest}
  defp block_param("pending"), do: {:ok, :pending}

  defp block_param(string_integer) when is_bitstring(string_integer) do
    case Integer.parse(string_integer) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp block_param(nil), do: {:ok, :latest}
  defp block_param(_), do: :error
end
