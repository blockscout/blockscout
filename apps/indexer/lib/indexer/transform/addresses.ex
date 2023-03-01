defmodule Indexer.Transform.Addresses do
  @moduledoc """
  Extract Addresses from data fetched from the Blockchain and structured as Blocks, InternalTransactions,
  Transactions and Logs.

  Address hashes are present in the Blockchain as a reference of a person that made/received an
  operation in the network. In BlockScout it's treated like a entity, such as the ones mentioned
  above.

  This module is responsible for collecting the hashes that are present as attributes in the already
  structured entities and structuring them as a list of unique Addresses.

  ## Attributes

  *@entity_to_extract_format_list*

  Defines a rule of where any attributes should be collected `:from` the input and how it should be
  mapped `:to` as a new attribute.

  For example:

      %{
        blocks: [
          [
            %{from: :block_number, to: :fetched_coin_balance_block_number},
            %{from: :miner_hash, to: :hash}
          ],
        # ...
      }

  The structure above means any item in `blocks` list that has a `:miner_hash` attribute should
  be mapped to a `hash` Address attribute.

  Each item in the `List`s relates to a single Address. So, having more than one attribute definition
  within an inner `List` means that the attributes are considered part of the same Address.

  For example:

      %{
        internal_transactions: [
          ...,
          [
            %{from: :block_number, to: :fetched_coin_balance_block_number},
            %{from: :created_contract_address_hash, to: :hash},
            %{from: :created_contract_code, to: :contract_code}
          ]
        ]
      }
  """

  alias Indexer.Helpers

  @entity_to_address_map %{
    address_coin_balances: [
      [
        %{from: :address_hash, to: :hash},
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :value, to: :fetched_coin_balance}
      ]
    ],
    blocks: [
      [
        %{from: :number, to: :fetched_coin_balance_block_number},
        %{from: :miner_hash, to: :hash}
      ]
    ],
    internal_transactions: [
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :from_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :to_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :created_contract_address_hash, to: :hash},
        %{from: :created_contract_code, to: :contract_code}
      ]
    ],
    codes: [
      [
        %{from: :code, to: :contract_code},
        %{from: :address, to: :hash}
      ]
    ],
    transactions: [
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :created_contract_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :from_address_hash, to: :hash},
        %{from: :nonce, to: :nonce}
      ],
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :to_address_hash, to: :hash}
      ]
    ],
    logs: [
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :address_hash, to: :hash}
      ]
    ],
    token_transfers: [
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :from_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :to_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :token_contract_address_hash, to: :hash}
      ]
    ],
    mint_transfers: [
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :from_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :to_address_hash, to: :hash}
      ]
    ],
    block_reward_contract_beneficiaries: [
      [
        %{from: :block_number, to: :fetched_coin_balance_block_number},
        %{from: :address_hash, to: :hash}
      ]
    ]
  }

  @typedoc """
  Parameters for `Explorer.Chain.Address.changeset/2`.
  """
  @type params :: %{
          required(:hash) => String.t(),
          required(:fetched_coin_balance_block_number) => non_neg_integer(),
          optional(:fetched_coin_balance) => non_neg_integer(),
          optional(:nonce) => non_neg_integer(),
          optional(:contract_code) => String.t()
        }

  defstruct pending: false

  @doc """
  Extract addresses from block, internal transaction, transaction, and log parameters.

  Blocks have their `miner_hash` extracted.

      iex> Indexer.Addresses.extract_addresses(
      ...>   %{
      ...>     blocks: [
      ...>       %{
      ...>         miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         number: 34
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_coin_balance_block_number: 34,
          hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
        }
      ]

  Internal transactions can have their `from_address_hash`, `to_address_hash` and/or `created_contract_address_hash`
  extracted.

      iex> Indexer.Addresses.extract_addresses(
      ...>   %{
      ...>     internal_transactions: [
      ...>       %{
      ...>         block_number: 1,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       },
      ...>       %{
      ...>         block_number: 2,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000002"
      ...>       },
      ...>       %{
      ...>         block_number: 3,
      ...>         created_contract_address_hash: "0x0000000000000000000000000000000000000003",
      ...>         created_contract_code: "0x"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_coin_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000001"
        },
        %{
          fetched_coin_balance_block_number: 2,
          hash: "0x0000000000000000000000000000000000000002"
        },
        %{
          contract_code: "0x",
          fetched_coin_balance_block_number: 3,
          hash: "0x0000000000000000000000000000000000000003"
        }
      ]

  Transactions can have their `from_address_hash` and/or `to_address_hash` extracted.

      iex> Indexer.Addresses.extract_addresses(
      ...>   %{
      ...>     transactions: [
      ...>       %{
      ...>         block_number: 1,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001",
      ...>         to_address_hash: "0x0000000000000000000000000000000000000002",
      ...>         nonce: 3
      ...>       },
      ...>       %{
      ...>         block_number: 2,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000003",
      ...>         nonce: 4
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_coin_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000001",
          nonce: 3
        },
        %{
          fetched_coin_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000002"
        },
        %{
          fetched_coin_balance_block_number: 2,
          hash: "0x0000000000000000000000000000000000000003",
          nonce: 4
        }
      ]

  Logs can have their `address_hash` extracted.

      iex> Indexer.Addresses.extract_addresses(
      ...>   %{
      ...>     logs: [
      ...>       %{
      ...>         address_hash: "0x0000000000000000000000000000000000000001",
      ...>         block_number: 1
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_coin_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000001"
        }
      ]

  When the same address is mentioned multiple times, the greatest `block_number` is used

      iex> Indexer.Addresses.extract_addresses(
      ...>   %{
      ...>     blocks: [
      ...>       %{
      ...>         miner_hash: "0x0000000000000000000000000000000000000001",
      ...>         number: 7
      ...>       },
      ...>       %{
      ...>         miner_hash: "0x0000000000000000000000000000000000000001",
      ...>         number: 6
      ...>       }
      ...>     ],
      ...>     internal_transactions: [
      ...>       %{
      ...>         block_number: 5,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       },
      ...>       %{
      ...>         block_number: 4,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       }
      ...>     ],
      ...>     transactions: [
      ...>       %{
      ...>         block_number: 3,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000001",
      ...>         nonce: 5
      ...>       },
      ...>       %{
      ...>         block_number: 2,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001",
      ...>         nonce: 4
      ...>       }
      ...>     ],
      ...>     logs: [
      ...>       %{
      ...>         address_hash: "0x0000000000000000000000000000000000000001",
      ...>         block_number: 1
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_coin_balance_block_number: 7,
          hash: "0x0000000000000000000000000000000000000001",
          nonce: 4
        }
      ]

  When a contract is created and then used in internal transactions and transaction in the same fetched data, the
  `created_contract_code` is merged with the greatest `block_number`

      iex> Indexer.Addresses.extract_addresses(
      ...>   %{
      ...>     internal_transactions: [
      ...>       %{
      ...>         block_number: 1,
      ...>         created_contract_code: "0x",
      ...>         created_contract_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       }
      ...>     ],
      ...>     transactions: [
      ...>       %{
      ...>         block_number: 2,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001",
      ...>         nonce: 4
      ...>       },
      ...>       %{
      ...>         block_number: 3,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000001",
      ...>         nonce: 5
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          contract_code: "0x",
          fetched_coin_balance_block_number: 3,
          hash: "0x0000000000000000000000000000000000000001",
          nonce: 4
        }
      ]

  All data must have some way of extracting the `fetched_coin_balance_block_number` or an `ArgumentError` will be raised when
  none of the supported extract formats matches the params.

  A contract's code is immutable: the same address cannot be bound to different code.  As such, different code will
  cause an error as something has gone terribly wrong with the chain if different code is written to the same address.
  """
  @spec extract_addresses(%{
          optional(:address_coin_balances) => [
            %{
              required(:address_hash) => String.t(),
              required(:block_number) => non_neg_integer(),
              required(:value) => non_neg_integer()
            }
          ],
          optional(:blocks) => [
            %{
              required(:miner_hash) => String.t(),
              required(:number) => non_neg_integer()
            }
          ],
          optional(:internal_transactions) => [
            %{
              required(:block_number) => non_neg_integer(),
              required(:from_address_hash) => String.t(),
              optional(:to_address_hash) => String.t(),
              optional(:created_contract_address_hash) => String.t(),
              optional(:created_contract_code) => String.t()
            }
          ],
          optional(:codes) => [
            %{
              required(:code) => String.t(),
              required(:address) => String.t(),
              required(:block_number) => non_neg_integer
            }
          ],
          optional(:transactions) => [
            %{
              required(:block_number) => non_neg_integer(),
              required(:from_address_hash) => String.t(),
              required(:nonce) => non_neg_integer(),
              optional(:to_address_hash) => String.t(),
              optional(:created_contract_address_hash) => String.t()
            }
          ],
          optional(:logs) => [
            %{
              required(:address_hash) => String.t(),
              required(:block_number) => non_neg_integer()
            }
          ],
          optional(:token_transfers) => [
            %{
              required(:from_address_hash) => String.t(),
              required(:to_address_hash) => String.t(),
              required(:token_contract_address_hash) => String.t(),
              required(:block_number) => non_neg_integer()
            }
          ],
          optional(:transaction_actions) => [
            %{
              required(:data) => map()
            }
          ],
          optional(:mint_transfers) => [
            %{
              required(:from_address_hash) => String.t(),
              required(:to_address_hash) => String.t(),
              required(:block_number) => non_neg_integer()
            }
          ],
          optional(:block_reward_contract_beneficiaries) => [
            %{
              required(:address_hash) => String.t(),
              required(:block_number) => non_neg_integer()
            }
          ]
        }) :: [params]
  def extract_addresses(fetched_data, options \\ []) when is_map(fetched_data) and is_list(options) do
    state = struct!(__MODULE__, options)

    addresses =
      for {entity_key, entity_fields} <- @entity_to_address_map,
          (entity_items = Map.get(fetched_data, entity_key)) != nil,
          do: extract_addresses_from_collection(entity_items, entity_fields, state)

    tx_actions_addresses =
      fetched_data
      |> Map.get(:transaction_actions, [])
      |> Enum.map(fn tx_action ->
        tx_action.data
        |> Map.get(:block_number)
        |> find_tx_action_addresses(tx_action.data)
      end)
      |> List.flatten()

    addresses
    |> Enum.concat(tx_actions_addresses)
    |> List.flatten()
    |> merge_addresses()
  end

  def extract_addresses_from_collection(items, fields, state),
    do: Enum.flat_map(items, &extract_addresses_from_item(&1, fields, state))

  def extract_addresses_from_item(item, fields, state), do: Enum.flat_map(fields, &extract_fields(&1, item, state))

  defp find_tx_action_addresses(block_number, data, accumulator \\ [])

  defp find_tx_action_addresses(block_number, data, accumulator) when is_map(data) or is_list(data) do
    Enum.reduce(data, accumulator, fn
      {_, value}, acc -> find_tx_action_addresses(block_number, value, acc)
      value, acc -> find_tx_action_addresses(block_number, value, acc)
    end)
  end

  defp find_tx_action_addresses(block_number, value, accumulator) when is_binary(value) do
    if Helpers.is_address_correct?(value) do
      [%{:fetched_coin_balance_block_number => block_number, :hash => value} | accumulator]
    else
      accumulator
    end
  end

  defp find_tx_action_addresses(_block_number, _value, accumulator), do: accumulator

  def merge_addresses(addresses) when is_list(addresses) do
    addresses
    |> Enum.group_by(fn address -> address.hash end)
    |> Enum.map(fn {_, similar_addresses} ->
      Enum.reduce(similar_addresses, &merge_addresses/2)
    end)
  end

  defp extract_fields(fields, item, state) when is_list(fields) do
    Enum.reduce_while(fields, [%{}], fn field, [acc] ->
      case extract_field(field, item, state) do
        {:ok, extracted} -> {:cont, [Map.merge(acc, extracted)]}
        :error -> {:halt, []}
      end
    end)
  end

  defp extract_field(%{from: from_attribute, to: to_attribute}, item, %__MODULE__{pending: pending}) do
    case Map.fetch(item, from_attribute) do
      {:ok, value} when not is_nil(value) or (to_attribute == :fetched_coin_balance_block_number and pending) ->
        {:ok, %{to_attribute => value}}

      _ ->
        :error
    end
  end

  # Ensure that when `:addresses` or `:address_coin_balances` are present, their :fetched_coin_balance will win
  defp merge_addresses(%{hash: hash} = first, %{hash: hash} = second) do
    merged_addresses =
      case {first[:fetched_coin_balance], second[:fetched_coin_balance]} do
        {nil, nil} ->
          first
          |> Map.merge(second)
          |> Map.put(
            :fetched_coin_balance_block_number,
            max_nil_last(
              Map.get(first, :fetched_coin_balance_block_number),
              Map.get(second, :fetched_coin_balance_block_number)
            )
          )

        {nil, _} ->
          # merge in `second` so its balance and block_number wins
          Map.merge(first, second)

        {_, nil} ->
          # merge in `first` so its balance and block_number wins
          Map.merge(second, first)

        {_, _} ->
          if greater_than_nil_last(
               Map.get(first, :fetched_coin_balance_block_number),
               Map.get(second, :fetched_coin_balance_block_number)
             ) do
            # merge in `first` so its block number wins
            Map.merge(second, first)
          else
            # merge in `second` so its block number wins
            Map.merge(first, second)
          end
      end

    merged_addresses
    |> Map.put(:nonce, max_nil_last(first[:nonce], second[:nonce]))
  end

  # `nil > 5 == true`, but we want numbers instead
  defp greater_than_nil_last(nil, nil), do: false
  defp greater_than_nil_last(nil, integer) when is_integer(integer), do: false
  defp greater_than_nil_last(integer, nil) when is_integer(integer), do: true

  defp greater_than_nil_last(first_integer, second_integer)
       when is_integer(first_integer) and is_integer(second_integer),
       do: first_integer > second_integer

  # max(nil, number) == nil, but we want numbers instead
  defp max_nil_last(nil, nil), do: nil
  defp max_nil_last(nil, integer) when is_integer(integer), do: integer
  defp max_nil_last(integer, nil) when is_integer(integer), do: integer

  defp max_nil_last(first_integer, second_integer)
       when is_integer(first_integer) and is_integer(second_integer),
       do: max(first_integer, second_integer)
end
