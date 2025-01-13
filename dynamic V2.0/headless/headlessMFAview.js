 export const HeadlessMfaView: FC = () => {
  const { user, userWithMissingInfo } = useDynamicContext();

  return (
    <div className="headless-mfa">
      {user || userWithMissingInfo ? <MfaView /> : <LogIn />}
    </div>
  );
};

export default function App() {
  return (
    <div className="App">
      <DynamicContextProvider
        settings={{
          environmentId: "YOUR_ENV_ID",
          walletConnectors: [EthereumWalletConnectors],
        }}
      >
        <HeadlessMfaView />
      </DynamicContextProvider>
    </div>
  );
}
