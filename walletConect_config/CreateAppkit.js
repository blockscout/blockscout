import { createAppKit } from '@reown/walletkit';
import { wagmiAdapter } from '@reown/walletkit/adapters/wagmi';
import { mainnet, arbitrumTestnet } from './networks';
import { projectId, metadata } from './config';

const modal = createAppKit({
  adapters: [wagmiAdapter],
  projectId,
  networks: [mainnet, arbitrumTestnet],
  metadata: metadata,
  features: {
    swaps: false // Optional - true by default
  }
});

export default modal;
