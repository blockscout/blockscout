defmodule Explorer.SmartContract.CertifiedSmartContractCatalogerTest do
  use Explorer.DataCase

  alias Explorer.SmartContract.CertifiedSmartContractCataloger
  alias Explorer.Chain.SmartContract

  setup do
    old_configuration = Application.get_env(:block_scout_web, :contract)
    certified_list = ["0xff9d236641962Cebf9DBFb54E7b8e91F99f10Db0", "0x0184245D202724dc28a2b688952Cb56C882c226F"]

    new_configuration =
      old_configuration
      |> Keyword.replace(:certified_list, certified_list)

    Application.put_env(:block_scout_web, :contract, new_configuration)

    on_exit(fn ->
      Application.put_env(:block_scout_web, :contract, old_configuration)
    end)

    {:ok, %{certified_list: certified_list}}
  end

  describe "start_link/1" do
    test "start_link/1 starts the GenServer" do
      assert {:ok, _pid} = CertifiedSmartContractCataloger.start_link([])
    end
  end

  describe "init/1" do
    test "init/1 sends :fetch_certified_smart_contracts message" do
      {:ok, _pid} = CertifiedSmartContractCataloger.init(:ok)
      assert_received :fetch_certified_smart_contracts
    end
  end

  describe "handle_info/2" do
    test "handle_info/2 updates certified flag", %{certified_list: certified_list} do
      address_1 = insert(:address, hash: Enum.at(certified_list, 0))
      address_2 = insert(:address, hash: Enum.at(certified_list, 1))

      insert(:smart_contract, address_hash: address_1.hash, contract_code_md5: "123")
      insert(:smart_contract, address_hash: address_2.hash, contract_code_md5: "123")

      assert {:ok, _pid} = CertifiedSmartContractCataloger.start_link([])
      :timer.sleep(100)

      smart_contract_1 = Repo.get_by(SmartContract, address_hash: address_1.hash)
      smart_contract_2 = Repo.get_by(SmartContract, address_hash: address_2.hash)

      assert smart_contract_1.certified == true
      assert smart_contract_2.certified == true
    end

    test "handle_info/2 removes certified flag for the smart-contracts from previous configuration", %{
      certified_list: certified_list
    } do
      address_1 = insert(:address, hash: Enum.at(certified_list, 0))
      address_2 = insert(:address, hash: Enum.at(certified_list, 1))

      insert(:smart_contract, address_hash: address_1.hash, contract_code_md5: "123", certified: true)
      insert(:smart_contract, address_hash: address_2.hash, contract_code_md5: "123", certified: true)

      old_configuration = Application.get_env(:block_scout_web, :contract)
      new_certified_list = ["0x6e8A77673109783001150DFA770E6c662f473DA9"]

      new_configuration =
        old_configuration
        |> Keyword.replace(:certified_list, new_certified_list)

      Application.put_env(:block_scout_web, :contract, new_configuration)

      address_3 = insert(:address, hash: Enum.at(new_certified_list, 0))
      insert(:smart_contract, address_hash: address_3.hash, contract_code_md5: "123")

      assert {:ok, _pid} = CertifiedSmartContractCataloger.start_link([])
      :timer.sleep(100)

      smart_contract_1 = Repo.get_by(SmartContract, address_hash: address_1.hash)
      smart_contract_2 = Repo.get_by(SmartContract, address_hash: address_2.hash)
      smart_contract_3 = Repo.get_by(SmartContract, address_hash: address_3.hash)

      assert smart_contract_1.certified == false
      assert smart_contract_2.certified == false
      assert smart_contract_3.certified == true
    end
  end
end
