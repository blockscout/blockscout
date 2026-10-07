[
    {"lib/ethereum_jsonrpc/rolling_window.ex", :improper_list_constr},
    {"lib/explorer/smart_contract/solidity/publisher_worker.ex", :pattern_match, 1},
    {"lib/explorer/smart_contract/solidity/publisher_worker.ex", :exact_eq, 9},
    {"lib/explorer/smart_contract/solidity/publisher_worker.ex", :pattern_match, 9},
    {"lib/explorer/smart_contract/vyper/publisher_worker.ex", :pattern_match, 1},
    {"lib/explorer/smart_contract/vyper/publisher_worker.ex", :exact_eq, 9},
    {"lib/explorer/smart_contract/vyper/publisher_worker.ex", :pattern_match, 9},
    {"lib/explorer/smart_contract/stylus/publisher_worker.ex", :pattern_match, 1},
    {"lib/explorer/smart_contract/stylus/publisher_worker.ex", :exact_eq, 15},
    {"lib/explorer/smart_contract/stylus/publisher_worker.ex", :pattern_match, 15},
    ~r/lib\/phoenix\/router.ex/,
    ~r/Poison\.Encoder/,
    # OTP 28 Dialyzer applies stricter opaqueness checks. Elixir inlines `MapSet.new()` (and thus
    # `Ecto.Multi.new()`, whose struct embeds a MapSet) and `%URI{}` literals at compile time, so
    # Dialyzer sees plain structs where the typespec declares an opaque type and reports false
    # positives for every `MapSet.member?/2`, `Ecto.Multi.run/3`, `URI.append_path/2`, etc. call.
    # See https://elixirforum.com/t/function-call-without-opaqueness-type-mismatch-under-otp-28/72407
    ~r/Type mismatch in call without opaque term in/,
    {"lib/utils/helper.ex", :contract_with_opaque}
]
