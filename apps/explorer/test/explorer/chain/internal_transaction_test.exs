defmodule Explorer.Chain.InternalTransactionTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Data, InternalTransaction, Wei}
  alias Explorer.Factory

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  doctest InternalTransaction

  describe "changeset/2" do
    test "with valid attributes" do
      transaction = insert(:transaction)

      changeset =
        InternalTransaction.changeset(%InternalTransaction{}, %{
          call_type: "call",
          from_address_hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
          gas: 100,
          gas_used: 100,
          index: 0,
          input: "0x70696e746f73",
          output: "0x72656672696564",
          to_address_hash: "0x6295ee1b4f6dd65047762f924ecd367c17eabf8f",
          trace_address: [0, 1],
          transaction_hash: transaction.hash,
          type: "call",
          value: 100,
          block_number: 35,
          block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          block_index: 0
        })

      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = InternalTransaction.changeset(%InternalTransaction{}, %{falala: "falafel"})
      refute changeset.valid?
    end

    test "that a valid changeset is persistable" do
      transaction = insert(:transaction)

      changeset =
        InternalTransaction.changeset(%InternalTransaction{}, %{
          call_type: "call",
          gas: 100,
          gas_used: 100,
          index: 0,
          input: "thin-mints",
          output: "munchos",
          trace_address: [0, 1],
          transaction: transaction,
          type: "call",
          value: 100
        })

      assert Repo.insert(changeset)
    end
  end

  defp call_type(opts) do
    defaults = [
      type: :call,
      call_type: :call,
      to_address_hash: Factory.address_hash(),
      from_address_hash: Factory.address_hash(),
      input: Factory.transaction_input(),
      output: Factory.transaction_input(),
      gas: Decimal.new(50_000),
      gas_used: Decimal.new(25_000),
      value: %Wei{value: 100},
      index: 0,
      trace_address: []
    ]

    struct!(InternalTransaction, Keyword.merge(defaults, opts))
  end

  defp create_type(opts) do
    defaults = [
      type: :create,
      from_address_hash: Factory.address_hash(),
      gas: Decimal.new(50_000),
      gas_used: Decimal.new(25_000),
      value: %Wei{value: 100},
      index: 0,
      init: Factory.transaction_input(),
      trace_address: []
    ]

    struct!(InternalTransaction, Keyword.merge(defaults, opts))
  end

  defp selfdestruct_type(opts) do
    defaults = [
      type: :selfdestruct,
      from_address_hash: Factory.address_hash(),
      to_address_hash: Factory.address_hash(),
      gas: Decimal.new(50_000),
      gas_used: Decimal.new(25_000),
      value: %Wei{value: 100},
      index: 0,
      trace_address: []
    ]

    struct!(InternalTransaction, Keyword.merge(defaults, opts))
  end

  describe "internal_transactions_to_raw" do
    test "it adds subtrace count" do
      transactions = [
        call_type(trace_address: []),
        call_type(trace_address: [0]),
        call_type(trace_address: [1]),
        call_type(trace_address: [2]),
        call_type(trace_address: [0, 0]),
        call_type(trace_address: [0, 1]),
        call_type(trace_address: [1, 0]),
        call_type(trace_address: [0, 0, 0]),
        call_type(trace_address: [0, 0, 1]),
        call_type(trace_address: [0, 0, 2]),
        call_type(trace_address: [0, 1, 0]),
        call_type(trace_address: [0, 1, 1])
      ]

      subtraces =
        transactions
        |> InternalTransaction.internal_transactions_to_raw()
        |> Enum.map(&Map.get(&1, "subtraces"))

      assert subtraces == [3, 2, 1, 0, 3, 2, 0, 0, 0, 0, 0, 0]
    end

    test "it correctly formats a call" do
      from = Factory.address_hash()
      to = Factory.address_hash()
      gas = 50_000
      gas_used = 25_000
      input = Factory.transaction_input()
      value = 50
      output = Factory.transaction_input()

      call_transaction =
        call_type(
          from_address_hash: from,
          to_address_hash: to,
          gas: Decimal.new(gas),
          gas_used: Decimal.new(gas_used),
          input: input,
          value: %Wei{value: value},
          output: output
        )

      [call] = InternalTransaction.internal_transactions_to_raw([call_transaction])

      assert call == %{
               "action" => %{
                 "callType" => "call",
                 "from" => to_string(from),
                 "gas" => integer_to_quantity(gas),
                 "input" => to_string(input),
                 "to" => to_string(to),
                 "value" => integer_to_quantity(value)
               },
               "result" => %{
                 "gasUsed" => integer_to_quantity(gas_used),
                 "output" => to_string(output)
               },
               "subtraces" => 0,
               "traceAddress" => [],
               "type" => "call"
             }
    end

    test "it correctly formats a create" do
      {:ok, contract_code} = Data.cast(Factory.contract_code_info().bytecode)
      contract_address = Factory.address_hash()
      from = Factory.address_hash()
      gas = 50_000
      gas_used = 25_000
      init = Factory.transaction_input()
      value = 50

      create_transaction =
        create_type(
          from_address_hash: from,
          created_contract_code: contract_code,
          created_contract_address_hash: contract_address,
          gas: Decimal.new(gas),
          gas_used: Decimal.new(gas_used),
          init: init,
          value: %Wei{value: value}
        )

      [create] = InternalTransaction.internal_transactions_to_raw([create_transaction])

      assert create == %{
               "action" => %{
                 "from" => to_string(from),
                 "gas" => integer_to_quantity(gas),
                 "init" => to_string(init),
                 "value" => integer_to_quantity(value)
               },
               "result" => %{
                 "address" => to_string(contract_address),
                 "code" => to_string(contract_code),
                 "gasUsed" => integer_to_quantity(gas_used)
               },
               "subtraces" => 0,
               "traceAddress" => [],
               "type" => "create"
             }
    end

    test "it correctly formats a selfdestruct" do
      from_address = Factory.address_hash()
      to_address = Factory.address_hash()

      value = 50

      selfdestruct_transaction =
        selfdestruct_type(
          to_address_hash: to_address,
          from_address_hash: from_address,
          value: %Wei{value: value}
        )

      [selfdestruct] = InternalTransaction.internal_transactions_to_raw([selfdestruct_transaction])

      assert selfdestruct == %{
               "action" => %{
                 "address" => to_string(from_address),
                 "balance" => integer_to_quantity(value),
                 "refundAddress" => to_string(to_address)
               },
               "subtraces" => 0,
               "traceAddress" => [],
               "type" => "suicide"
             }
    end
  end
end
