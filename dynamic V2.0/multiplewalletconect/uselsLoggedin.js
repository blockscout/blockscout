 import { useIsLoggedIn } from "@dynamic-labs/sdk-react-core";

const isLoggedIn = useIsLoggedIn();

return <>{isLoggedIn ? <Profile /> : </Login>}</>
