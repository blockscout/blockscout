# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.BatchCorrelationTest do
  use ExUnit.Case, async: true

  import Mox

  alias EthereumJSONRPC.BatchCorrelation

  setup :verify_on_exit!

  setup do
    EthereumJSONRPC.Case.Nethermind.Mox.setup()
  end

  @id_to_params %{0 => :a, 1 => :b}

  defp requests(id_to_params) do
    Enum.map(id_to_params, fn {id, param} ->
      EthereumJSONRPC.request(%{id: id, method: "test_method", params: [to_string(param)]})
    end)
  end

  describe "correlate_responses/2" do
    test "matches replies by id, not by position" do
      responses = [%{id: 1, result: "b"}, %{id: 0, result: "a"}]

      assert {^responses, [], []} = BatchCorrelation.correlate_responses(responses, @id_to_params)
    end

    test "returns the requested ids left without a reply" do
      assert {[%{id: 1, result: "b"}], [], [0]} =
               BatchCorrelation.correlate_responses([%{id: 1, result: "b"}], @id_to_params)
    end

    test "leaves replies with a repeated or not requested id uncorrelated" do
      first = %{id: 0, result: "a"}
      repeated = %{id: 0, result: "a again"}
      not_requested = %{id: 7, error: %{message: "boom"}}

      assert {[^first], [^repeated, ^not_requested], [1]} =
               BatchCorrelation.correlate_responses([first, repeated, not_requested], @id_to_params)
    end

    test "attributes a reply without an id to the only request of a batch" do
      error = %{message: "boom"}

      assert {[%{id: 5, error: ^error}], [], []} =
               BatchCorrelation.correlate_responses([%{id: nil, error: error}], %{5 => :a})
    end

    test "does not attribute a reply without an id in a batch of several requests" do
      id_less = %{id: nil, error: %{message: "boom"}}

      # exactly one request is left without a reply, but the reply can still be
      # an error of a whole chunk of the batch
      assert {[%{id: 0}], [^id_less], [1]} =
               BatchCorrelation.correlate_responses([%{id: 0, result: "a"}, id_less], @id_to_params)
    end
  end

  describe "check_errors/3" do
    test "returns :ok when there are no error replies" do
      assert :ok = BatchCorrelation.check_errors([%{id: 0, result: "a"}], [%{id: nil, result: "b"}], & &1)
    end

    test "removes the block number of an error that cannot be attributed" do
      uncorrelated = [
        %{id: nil, error: %{message: "boom", data: %{"blockNumber" => 99, "reason" => "kept"}}},
        %{id: nil, error: %{message: "boom", data: %{block_number: 99}}},
        %{id: nil, error: %{message: "boom", data: "kept"}}
      ]

      # the block to refetch must only come from an attributed error
      assert {:error,
              [
                %{message: "boom", data: data},
                %{message: "boom", data: empty_data},
                %{message: "boom", data: "kept"}
              ]} = BatchCorrelation.check_errors([], uncorrelated, & &1)

      assert data == %{"reason" => "kept"}
      assert empty_data == %{}
    end

    test "annotates attributed errors and returns uncorrelated ones as they are" do
      uncorrelated_error = %{message: "unattributable"}

      assert {:error, [%{message: "attributed", data: :a}, ^uncorrelated_error]} =
               BatchCorrelation.check_errors(
                 [%{id: 0, error: %{message: "attributed"}}, %{id: 1, result: "b"}],
                 [%{id: nil, error: uncorrelated_error}],
                 fn %{id: id, error: error} -> Map.put(error, :data, Map.fetch!(@id_to_params, id)) end
               )
    end
  end

  describe "check_no_missing_responses/2" do
    test "returns :ok when every request got a reply" do
      assert :ok = BatchCorrelation.check_no_missing_responses([], @id_to_params)
    end

    test "returns the params of the requests left without a reply" do
      assert {:error, {:missing_responses, [:b]}} = BatchCorrelation.check_no_missing_responses([1], @id_to_params)
    end
  end

  describe "fetch/3" do
    test "sends a completely answered batch once", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: 0}, %{id: 1}], _ ->
        {:ok, [%{id: 1, result: "b"}, %{id: 0, result: "a"}]}
      end)

      assert {:ok, {[%{id: 1}, %{id: 0}], [], []}, :ok} =
               BatchCorrelation.fetch(@id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "sends the requests left without a reply separately and keeps the received replies", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      error = %{message: "boom"}

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: 0}, %{id: 1}], _ -> {:ok, [%{id: 0, result: "a"}, %{id: nil, error: error}]} end)
      # the reply without an id is attributable in a batch of a single request
      |> expect(:json_rpc, fn [%{id: 1, params: ["b"]}], _ -> {:ok, [%{id: nil, error: error}]} end)

      assert {:ok, {[%{id: 0, result: "a"}, %{id: 1, error: ^error}], [], []}, :ok} =
               BatchCorrelation.fetch(@id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "returns the requests that are still left without a reply", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: 0}, %{id: 1}], _ -> {:ok, [%{id: 0, result: "a"}]} end)
      |> expect(:json_rpc, fn [%{id: 1}], _ -> {:ok, []} end)

      assert {:ok, {[%{id: 0}], [], [1]}, :ok} =
               BatchCorrelation.fetch(@id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "keeps the id-less error of the batch when a separate request gets no reply", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      id_less = %{id: nil, error: %{message: "boom"}}

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: 0}, %{id: 1}], _ -> {:ok, [%{id: 0, result: "a"}, id_less]} end)
      |> expect(:json_rpc, fn [%{id: 1}], _ -> {:ok, []} end)

      # the error is the only reply left for the request, so it isn't dropped
      assert {:ok, {[%{id: 0}], [^id_less], [1]}, :ok} =
               BatchCorrelation.fetch(@id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "does not multiply a batch that failed in every chunk into separate requests", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      id_to_params = %{0 => :a, 1 => :b, 2 => :c, 3 => :d}
      id_less = %{id: nil, error: %{message: "rate limited"}}

      # the transport flattens the replies of the chunks: one reply per chunk
      # of two requests, exactly one call
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [_, _, _, _], _ -> {:ok, [id_less, id_less]} end)

      assert {:ok, {[], [^id_less, ^id_less], [0, 1, 2, 3]}, :ok} =
               BatchCorrelation.fetch(id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "does not multiply a batch that failed as a whole into separate requests", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      id_less = %{id: nil, error: %{message: "rate limited"}}

      # exactly one call
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: 0}, %{id: 1}], _ -> {:ok, [id_less]} end)

      assert {:ok, {[], [^id_less], [0, 1]}, :ok} =
               BatchCorrelation.fetch(@id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "returns the replies of the batch with the failure of a separate request", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      id_less = %{id: nil, error: %{message: "boom"}}

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: 0}, %{id: 1}], _ -> {:ok, [%{id: 0, result: "a"}, id_less]} end)
      |> expect(:json_rpc, fn [%{id: 1}], _ -> {:error, :timeout} end)

      assert {:ok, {[%{id: 0}], [^id_less], [1]}, {:error, :timeout}} =
               BatchCorrelation.fetch(@id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "returns the failed request and the ones not sent after it as unmatched", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      id_to_params = %{0 => :a, 1 => :b, 2 => :c, 3 => :d}

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [_, _, _, _], _ -> {:ok, [%{id: 0, result: "a"}]} end)
      |> expect(:json_rpc, fn [%{id: 1}], _ -> {:ok, [%{id: 1, result: "b"}]} end)
      |> expect(:json_rpc, fn [%{id: 2}], _ -> {:error, :timeout} end)

      # the request of id 3 is not sent
      assert {:ok, {[%{id: 0}, %{id: 1}], [], [2, 3]}, {:error, :timeout}} =
               BatchCorrelation.fetch(id_to_params, &requests/1, json_rpc_named_arguments)
    end

    test "returns the failure of the batch request", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: 0}, %{id: 1}], _ -> {:error, :timeout} end)

      assert {:error, :timeout} = BatchCorrelation.fetch(@id_to_params, &requests/1, json_rpc_named_arguments)
    end
  end
end
