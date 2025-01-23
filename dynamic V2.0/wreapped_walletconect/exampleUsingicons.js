 import { BitcoinIcon } from '@dynamic-labs/iconic';

<DynamicContextProvider
  settings={{
    overrides: {
      views: [
        {
          type: 'wallet-list',
          tabs: {
            items: [
              {
                text: 'Ethereum',
                icon: <BitcoinIcon />
              }
            ]
          }
        }
      ]
    }
  }}
>
  {/* Add your application components here */}
</DynamicContextProvider>
