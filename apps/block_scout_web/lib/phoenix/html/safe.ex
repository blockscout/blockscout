alias Explorer.Chain
alias Explorer.Chain.{Address, Block, Data, Hash, Transaction}

defimpl Phoenix.HTML.Safe, for: Address do
  def to_iodata(%@for{} = address) do
    @for.checksum(address, true)
  end
end

defimpl Phoenix.HTML.Safe, for: Transaction do
  def to_iodata(%@for{hash: hash}) do
    @protocol.to_iodata(hash)
  end
end

defimpl Phoenix.HTML.Safe, for: Block do
  def to_iodata(%@for{number: number}) do
    @protocol.to_iodata(number)
  end
end

defimpl Phoenix.HTML.Safe, for: Data do
  def to_iodata(data) do
    Chain.data_to_iodata(data)
  end
end

defimpl Phoenix.HTML.Safe, for: Hash do
  def to_iodata(hash) do
    Chain.hash_to_iodata(hash)
  end
end
