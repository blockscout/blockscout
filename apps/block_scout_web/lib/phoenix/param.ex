alias Explorer.Chain.{Address, Block, Hash, Transaction}

defimpl Phoenix.Param, for: Transaction do
  def to_param(%@for{hash: hash}) do
    @protocol.to_param(hash)
  end
end

defimpl Phoenix.Param, for: Address do
  def to_param(%@for{} = address) do
    @for.checksum(address)
  end
end

defimpl Phoenix.Param, for: Block do
  def to_param(%@for{consensus: true, number: number}) do
    to_string(number)
  end

  def to_param(%@for{consensus: false, hash: hash}) do
    to_string(hash)
  end
end

defimpl Phoenix.Param, for: Hash do
  def to_param(hash) do
    to_string(hash)
  end
end

defimpl Phoenix.Param, for: Decimal do
  def to_param(decimal) do
    to_string(decimal)
  end
end
