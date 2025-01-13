 import { useAuthenticateConnectedUser, useDynamicContext } from "@dynamic-labs/sdk-react-core";

const Element = () => {
  const { user } = useDynamicContext();
  const { authenticateUser, isAuthenticating } = useAuthenticateConnectedUser();

  if (!user) {
    return (
      <button onClick={authenticateUser} disabled={isAuthenticating}>
        Authenticate user
      </button>;
    )
  }

  return <div>User is authenticated!</div>;
};
