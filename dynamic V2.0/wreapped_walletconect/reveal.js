import { useEmbeddedReveal } from "@dynamic-labs/sdk-react-core";
import { useState } from "react";

export default function ExportWalletButton() {
  const { initExportProcess } = useEmbeddedReveal();
  const [isExporting, setIsExporting] = useState(false);
  const [error, setError] = useState(null);

  const handleExport = async () => {
    try {
      setIsExporting(true);
      setError(null);
      await initExportProcess();
    } catch (err) {
      setError(err.message || "Failed to export wallet");
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div>
      <button 
        onClick={handleExport} 
        disabled={isExporting}
        aria-busy={isExporting}
      >
        {isExporting ? "Exporting..." : "Export Wallet"}
      </button>
      {error && <p className="error">{error}</p>}
    </div>
  );
}
