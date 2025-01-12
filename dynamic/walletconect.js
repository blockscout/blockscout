import {
  DynamicContextProvider,
  FilterChain,
} from "@dynamic-labs/sdk-react-core";
import {
  BitcoinIcon,
  EthereumIcon,
  FlowIcon,
  SolanaIcon,
} from "@dynamic-labs/iconic";

const App = () => {
  return (
    <DynamicContextProvider
      settings={{
        environmentId: "env-id",
        // Additional settings...

        overrides: {
          views: [
            {
              type: "wallet-list",
              tabs: {
                items: [
                  {
                    label: { text: "All chains" },
                  },
                  {
                    label: { icon: <EthereumIcon /> },
                    walletsFilter: FilterChain("EVM"),
                    recommendedWallets: [
                      {
                        walletKey: "phantomevm",
                      },
                    ],
                  },
                  {
                    label: { icon: <SolanaIcon /> },
                    walletsFilter: FilterChain("SOL"),
                  },
                  {
                    label: { icon: <BitcoinIcon /> },
                    walletsFilter: FilterChain("BTC"),
                  },
                  {
                    label: { icon: <FlowIcon /> },
                    walletsFilter: FilterChain("FLOW"),
                  },
                ],
              },
            },
          ],
        },
      }}
    ></DynamicContextProvider>
  );
};
