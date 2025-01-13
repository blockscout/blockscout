 const locale = {
  en: {
    dyn_send_transaction: {
      confirmation: {
        title: "My New Title",
      },
    },
  }
};

<DynamicContextProvider settings={settings} locale={locale}>
  <MyApp />
</DynamicContextProvider>
