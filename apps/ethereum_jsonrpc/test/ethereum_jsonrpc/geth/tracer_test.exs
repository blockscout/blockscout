defmodule EthereumJSONRPC.Geth.TracerTest do
  use EthereumJSONRPC.Case, async: false

  import ExUnit.CaptureLog

  alias EthereumJSONRPC.Geth
  alias EthereumJSONRPC.Geth.{Calls, Tracer}

  describe "replay/3" do
    test "same as callTracer" do
      struct_logs = File.read!(File.cwd!() <> "/test/support/fixture/geth/trace/struct_logger.json") |> Jason.decode!()

      transaction = "0xa0a5c30c5c5ec22b3346e0ae5ce09f8f41faf54f68a2a113eb15e363af90e9ab"

      sl_calls =
        Tracer.replay(struct_logs["result"], struct_logs["receipt"], struct_logs["tx"])
        |> Stream.with_index()
        |> Enum.map(fn {trace, index} ->
          Map.merge(trace, %{
            "blockNumber" => 0,
            "index" => index,
            "transactionIndex" => 0,
            "transactionHash" => transaction
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
            "transactionHash" => transaction
          })
        end)
        |> Calls.to_internal_transactions_params()

      assert sl_calls == ct_calls

      Application.put_env(:ethereum_jsonrpc, Geth, tracer: init_tracer)
    end
  end

  describe "prepare_calls/1 with call_tracer" do
    setup do
      original_config = Application.get_env(:ethereum_jsonrpc, Geth)
      updated_config = Keyword.put(original_config, :tracer, "call_tracer")
      Application.put_env(:ethereum_jsonrpc, Geth, updated_config)

      on_exit(fn ->
        Application.put_env(:ethereum_jsonrpc, Geth, original_config)
      end)

      :ok
    end

    test "does not emit a warning for DELEGATECALL type without 'from' field" do
      call = %{"type" => "DELEGATECALL", "to" => "0xabc"}

      log =
        capture_log(fn ->
          Geth.prepare_calls(call)
        end)

      refute log =~ "unknown type"
    end

    test "does not emit a warning for STATICCALL type without 'from' field" do
      call = %{"type" => "STATICCALL", "to" => "0xabc"}

      log =
        capture_log(fn ->
          Geth.prepare_calls(call)
        end)

      refute log =~ "unknown type"
    end

    test "still emits a warning for a truly unknown call type" do
      call = %{"type" => "UNKNOWN", "from" => "0xabc", "to" => "0xdef"}

      log =
        capture_log(fn ->
          Geth.prepare_calls(call)
        end)

      assert log =~ "unknown type"
    end
  end
end
