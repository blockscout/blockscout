defmodule EthereumJSONRPC.Geth.TracerTest do
  use EthereumJSONRPC.Case, async: false

  alias EthereumJSONRPC.Geth
  alias EthereumJSONRPC.Geth.{Calls, Tracer}

  describe "replay/3" do
    test "same as callTracer" do
      struct_logs = File.read!(File.cwd!() <> "/test/support/fixture/geth/trace/struct_logger.json") |> Jason.decode!()

      tx = "0xa0a5c30c5c5ec22b3346e0ae5ce09f8f41faf54f68a2a113eb15e363af90e9ab"

      sl_calls =
        Tracer.replay(struct_logs["result"], struct_logs["receipt"], struct_logs["tx"])
        |> Stream.with_index()
        |> Enum.map(fn {trace, index} ->
          Map.merge(trace, %{
            "blockNumber" => 0,
            "index" => index,
            "transactionIndex" => 0,
            "transactionHash" => tx
          })
        end)
        |> Calls.to_internal_transactions_params()

      init_tracer = Application.get_env(:ethereum_jsonrpc, Geth, :tracer)
      Application.put_env(:ethereum_jsonrpc, Geth, tracer: "call_tracer")

      calls =
        File.read!(File.cwd!() <> "/test/support/fixture/geth/trace/calltracer.json")
        |> Jason.decode!()
        |> Map.get("result")

      ct_calls =
        calls
        |> Geth.prepare_calls()
        |> Stream.with_index()
        |> Enum.map(fn {trace, index} ->
          Map.merge(trace, %{
            "blockNumber" => 0,
            "index" => index,
            "transactionIndex" => 0,
            "transactionHash" => tx
          })
        end)
        |> Calls.to_internal_transactions_params()

      assert sl_calls == ct_calls

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: init_tracer)
    end
  end
end
