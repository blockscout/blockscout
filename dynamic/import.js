import React from "react";
import { useDynamicContext } from "@dynamic-labs/sdk-react-core";

/**
 * Component for a button that opens the Ethereum tab by default.
 */
const ConnectWithEthereum: React.FC = () => {
  const { setShowAuthFlow, setSelectedTabIndex } = useDynamicContext();

  /**
   * Handles the button click event by setting the default tab to Ethereum and showing the authentication flow.
   */
  const onClickHandler = (): void => {
    setSelectedTabIndex(1); // Set the selected tab index to 1, which corresponds to the Ethereum tab
    setShowAuthFlow(true);
  };

  return <button onClick={onClickHandler}>Connect with Ethereum wallet</button>;
};

export default ConnectWithEthereum;
