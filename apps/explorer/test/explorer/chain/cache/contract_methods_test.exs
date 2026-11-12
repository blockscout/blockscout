# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.ContractMethodsTest do
  use Explorer.DataCase, async: false

  import Explorer.QuerySources, only: [with_query_sources: 1]

  alias Explorer.Chain.Cache.ContractMethods
  alias Explorer.Chain.{ContractMethod, Data, MethodIdentifier}

  setup do
    config = Application.get_env(:explorer, ContractMethods) || []
    Application.put_env(:explorer, ContractMethods, Keyword.merge(config, enabled: true))
    on_exit(fn -> Application.put_env(:explorer, ContractMethods, config) end)

    :ok
  end

  describe "find_contract_methods/2" do
    test "returns the same methods on repeated lookups of the same id" do
      contract_method = insert(:contract_method)
      {:ok, method_id} = MethodIdentifier.cast(contract_method.identifier)
      on_exit(fn -> ConCache.delete(ContractMethods.cache_name(), {:contract_method, method_id}) end)

      assert [%ContractMethod{identifier: ^method_id}] = ContractMethods.find_contract_methods([method_id], [])

      # served from the cache now, without a DB query
      {result, sources} = with_query_sources(fn -> ContractMethods.find_contract_methods([method_id], []) end)

      assert [%ContractMethod{identifier: ^method_id}] = result
      refute "contract_methods" in sources
    end

    test "caches ids without known methods and still returns methods for the known ones" do
      contract_method = insert(:contract_method)
      {:ok, known_id} = MethodIdentifier.cast(contract_method.identifier)
      unknown_id = %Data{bytes: <<0xDE, 0xAD, 0xBE, 0xEF>>}

      on_exit(fn ->
        ConCache.delete(ContractMethods.cache_name(), {:contract_method, known_id})
        ConCache.delete(ContractMethods.cache_name(), {:contract_method, unknown_id})
      end)

      assert [%ContractMethod{identifier: ^known_id}] =
               ContractMethods.find_contract_methods([known_id, unknown_id], [])

      {result, sources} =
        with_query_sources(fn -> ContractMethods.find_contract_methods([known_id, unknown_id], []) end)

      assert [%ContractMethod{identifier: ^known_id}] = result
      refute "contract_methods" in sources
    end
  end
end
