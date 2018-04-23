alias Explorer.Chain
alias Explorer.Chain.Hash

defimpl Phoenix.HTML.Safe, for: Hash do
  def to_iodata(hash) do
    Chain.hash_to_iodata(hash)
  end
end
