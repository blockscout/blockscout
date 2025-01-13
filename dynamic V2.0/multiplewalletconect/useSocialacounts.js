 import { useSocialAccounts } from "@dynamic-labs/sdk-react-core";
import { SocialIcon } from '@dynamic-labs/iconic';

const Avatar = ({ avatarUrl }) => {
  return (
    <div className="avatar">
      <img src={avatarUrl} alt="avatar" />
    </div>
  );
};


const Icon = ({ provider }) => {
  return (
    <div className="icon-container">
    <SocialIcon name={provider} />
    </div>
  );
};

const UserProfileSocialAccount = ({ provider }) => {
  const {
    linkSocialAccount,
    unlinkSocialAccount,
    isProcessing,
    isLinked,
    getLinkedAccountInformation,
  } = useSocialAccounts();

  const isProviderLinked = isLinked(provider);
  const connectedAccountInfo = getLinkedAccountInformation(provider);

  return (
    <Flex>
      <div className="icon">
        {isProviderLinked ? (
          <Avatar avatarUrl={connectedAccountInfo?.avatar} />
        ) : (
          <Icon provider={provider} />
        )}
      </div>
      <div className="label">
        <p>{connectedAccountInfo?.publicIdentifier ?? provider}</p>
      </div>
      {isProviderLinked ? (
        <button
          onClick={() => unlinkSocialAccount(provider)}
          loading={isProcessing}
        >
          Disconnect
        </button>
      ) : (
        <button
          onClick={() => linkSocialAccount(provider)}
          loading={isProcessing}
        >
          Connect
        </button>
      )}
    </Flex>
  );
};

const Socials = () => {
  const providers = [
    "discord",
    "facebook",
    "github",
    "google",
    "instagram",
    "twitch",
    "twitter",
  ];

  return (
    <Flex direction="column" align="stretch">
      {providers.map((provider) => (
        <UserProfileSocialAccount provider={provider} />
      ))}
    </Flex>
  );
};
