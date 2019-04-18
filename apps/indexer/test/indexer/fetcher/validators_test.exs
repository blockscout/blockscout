defmodule Indexer.Fetcher.ValidatorsTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address
  alias Indexer.Fetcher.Validators

  @moduletag :capture_log

  setup :set_mox_global

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    :ok
  end

  test "import validators" do
    validators_list_mox_ok()
    validator_metadata_mox_ok()

    Validators.Supervisor.Case.start_supervised!()

    found_validator =
      wait(fn ->
        Repo.one!(from(n in Address.Name, where: fragment("(metadata->>'type')::text = 'validator'")))
      end)

    assert found_validator.name == "Testname Unitarion"
  end

  defp validators_list_mox_ok() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      1,
      fn [%{id: id}], _opts ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result:
               "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
           }
         ]}
      end
    )
  end

  defp validator_metadata_mox_ok() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      1,
      fn [%{id: id}], _opts ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result:
               "0x546573746e616d65000000000000000000000000000000000000000000000000556e69746172696f6e000000000000000000000000000000000000000000000030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140585800000000000000000000000000000000000000000000000000000000000030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003afe130e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000058585858585858207374726565742058585858585800000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
           }
         ]}
      end
    )
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
