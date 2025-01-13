 import { useDynamicContext } from "@dynamic-labs/sdk-react-core";

<DynamicContextProvider
  settings={{
    initialAuthenticationMode: 'connect-and-sign', // this is the default option
    ...
  }}
>
  {...}
</DynamicContextProvider>
