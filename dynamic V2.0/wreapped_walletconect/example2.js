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
            {
              type: SdkViewSectionType.Separator,
              label: "Or",
            },
            {
              type: SdkViewSectionType.Social,
              defaultItem: "google",
            },
          ],
        },
      ]
    }
  }}
>
  <App />
</DynamicContextProvider>;
