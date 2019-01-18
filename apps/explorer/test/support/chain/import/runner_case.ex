defmodule Explorer.Chain.Import.RunnerCase do
  import Explorer.Factory, only: [insert: 2]
  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.{Address, Token}
  alias Explorer.Repo

  def insert_address_with_token_balances(%{
        previous: %{value: previous_value},
        current: %{block_number: current_block_number, value: current_value},
        token_contract_address_hash: token_contract_address_hash
      }) do
    %Address.TokenBalance{
      address_hash: address_hash,
      token_contract_address_hash: ^token_contract_address_hash
    } =
      insert(:token_balance,
        token_contract_address_hash: token_contract_address_hash,
        block_number: current_block_number - 1,
        value: previous_value
      )

    address = Repo.get(Address, address_hash)

    insert_token_balance(%{
      address: address,
      token_contract_address_hash: token_contract_address_hash,
      block_number: current_block_number,
      value: current_value
    })

    address
  end

  def insert_token_balance(%{
        address: %Address{hash: address_hash} = address,
        token_contract_address_hash: token_contract_address_hash,
        block_number: block_number,
        value: value
      }) do
    %Address.TokenBalance{
      address_hash: ^address_hash,
      token_contract_address_hash: ^token_contract_address_hash,
      block_number: ^block_number,
      value: cast_value
    } =
      insert(:token_balance,
        address: address,
        token_contract_address_hash: token_contract_address_hash,
        block_number: block_number,
        value: value
      )

    %Address.CurrentTokenBalance{
      address_hash: ^address_hash,
      token_contract_address_hash: ^token_contract_address_hash,
      block_number: ^block_number,
      value: ^cast_value
    } =
      insert(:address_current_token_balance,
        address: address,
        token_contract_address_hash: token_contract_address_hash,
        block_number: block_number,
        value: value
      )
  end

  def update_holder_count!(contract_address_hash, holder_count) do
    {1, [%{holder_count: ^holder_count}]} =
      Repo.update_all(
        from(token in Token,
          where: token.contract_address_hash == ^contract_address_hash,
          select: map(token, [:holder_count])
        ),
        set: [holder_count: holder_count]
      )
  end
end
