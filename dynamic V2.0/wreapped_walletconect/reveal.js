import { useEmbeddedReveal } from "@dynamic-labs/sdk-react-core";

export default function ExportWalletButton() {
  const { initExportProcess } = useEmbeddedReveal();

  return (
    <button onClick={() => initExportProcess()}>Export Wallet</button>
  );
}
