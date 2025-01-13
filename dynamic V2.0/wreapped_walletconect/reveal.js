 import { useEmbeddedReveal } from "@dynamic-labs/sdk-react-core";


const { initExportProcess } = useEmbeddedReveal();


<button onClick={() => initExportProcess()}>Export Wallet</button>;
