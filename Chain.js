etherscan: {
  enable: true,
    apiKey: {
      buildbear: "verifyContract",
    },
    customChains: [
      {
        network: "curly sand man",
        chainId: 21548,
        urls: {
          apiURL: "https://rpc.buildbear.io/verify/etherscan/curly-sandman-10c6e11a",
          browserURL: "https://curly-sandman-10c6e11a.blockscout.buildbear.io",
        },
      },
    ],
  }
