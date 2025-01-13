 import { SdkViewSectionType, SdkViewType } from "@dynamic-labs/sdk-api";

<DynamicContextProvider
  settings={{
    overrides: {
      views: [
        {
          type: SdkViewType.Login,
          sections: [
            {
              type: SdkViewSectionType.Email,
            },
          ],
        },
      ]
    }
  }}
>
  <App />
</DynamicContextProvider>;
