defmodule BlockScoutWeb.HtmlView do
    use BlockScoutWeb, :view

    alias Explorer.Stats

    def attestationCount() do
        "Attestation Count: #{Stats.attestation_count()}"
    end

    def vanityCount() do
        "Vanity Count: #{Stats.vanity_count()}"
    end

    def lastTransactionTimeStamp() do
        "Last Transaction: #{Stats.transaction_time()} minutes ago."
    end


    
end