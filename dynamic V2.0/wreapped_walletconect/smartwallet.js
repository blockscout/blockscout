 <DynamicContextProvider
   settings={{
      ...,
      newToWeb3WalletChainMap: {
         primary_chain: 'evm',
         wallets: {
           evm: 'coinbase'
         },
      },
   }}>
   <HomePage />
</DynamicContextProvider>
