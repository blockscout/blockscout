import Config

config :block_scout_web,
  defi: [
    %{title: "Moola", url: "https://moola.market/"},
    %{title: "Pinnata", url: "https://www.pinnata.xyz/farm#/"},
    %{title: "GoodGhosting", url: "https://goodghosting.com/"},
    %{title: "Revo", url: "https://revo.market/"},
    %{title: "ImmortalDao Finance", url: "https://www.immortaldao.finance"}
  ],
  swap: [
    %{title: "Ubeswap", url: "https://ubeswap.org/"},
    %{title: "Symmetric", url: "https://symmetric.finance/"},
    %{title: "Mobius", url: "https://www.mobius.money/"},
    %{title: "Mento-fi", url: "https://mento.finance/"},
    %{title: "Swap Bitssa", url: "https://swap.bitssa.com/"}
  ],
  wallet_list: [
    %{title: "Valora", url: "https://valoraapp.com/"},
    %{title: "Celo Terminal", url: "https://celoterminal.com/"},
    %{title: "Celo Wallet", url: "https://celowallet.app/"},
    %{title: "Node Wallet", url: "https://www.nodewallet.xyz/"}
  ],
  nft_list: [
    %{title: "Niftydrop", url: "https://niftydrop.net/"},
    %{title: "NFT Viewer", url: "https://nfts.valoraapp.com/"},
    %{title: "Cyberbox", url: "https://cyberbox.art/"},
    %{title: "Nomspace", url: "https://nom.space/"},
    %{title: "Alities", url: "https://alities.io/"}
  ],
  connect_list: [
    %{title: "impactMarket", url: "https://impactmarket.com/"},
    %{title: "Talent Protocol", url: "https://talentprotocol.com/"},
    %{title: "Doni", url: "https://doni.app/"}
  ],
  spend_list: [
    %{title: "Bidali", url: "https://giftcards.bidali.com/"},
    %{title: "Flywallet", url: "https://flywallet.io/"},
    %{title: "ChiSpend", url: "https://chispend.com/"}
  ],
  finance_tools_list: [
    %{title: "Celo Tracker", url: "https://celotracker.com/"},
    %{title: "celo.tax", url: "https://celo.tax/"},
    %{title: "Trelis", url: "https://trelis.com/"}
  ],
  resources: [
    %{title: "Celo Vote", url: "https://celovote.com/"},
    %{title: "Celo Forum", url: "https://forum.celo.org/"},
    %{title: "TheCelo", url: "https://thecelo.com/"},
    %{title: "Validators", url: "https://celo.org/validators/explore"},
    %{title: "Celo Reserve", url: "https://celoreserve.org/"},
    %{title: "Celo Docs", url: "https://docs.celo.org/"}
  ],
  learning: [
    %{title: "Celo Whitepaper", url: "https://celo.org/papers/whitepaper"},
    %{title: "Learn Celo", url: "https://learn.figment.io/protocols/celo"},
    %{title: "Coinbase Earn", url: "https://www.coinbase.com/price/celo"}
  ],
  other_networks: [
    %{title: "Celo Mainnet", url: "https://explorer.celo.org/mainnet", test_net?: false},
    %{title: "Celo Alfajores", url: "https://explorer.celo.org/alfajores", test_net?: true},
    %{title: "Celo Baklava", url: "https://explorer.celo.org/baklava", test_net?: true},
    %{title: "Celo Cannoli", url: "https://explorer.celo.org/cannoli", test_net?: true}
  ]
