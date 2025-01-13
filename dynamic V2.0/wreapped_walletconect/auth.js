 import { useDynamicContext } from "@dynamic-labs/sdk-react-core"; //later you will read about dynamicContext

const HomePage = () => {
  const { primaryWallet, user } = useDynamicContext();

  if (primaryWallet !== null || user) {
    return (
      <div className={styles.logged_in}>
        <WalletKitActions />
      </div>
    );
  }

  return <LoginView />;
};
