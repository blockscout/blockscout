defmodule Explorer.Stats do

    alias Explorer.Repo

    import Ecto.Query, only: [from: 2]


    
    def attestation_count() do
        query = from(l in "logs",
                where: l.address_hash == "\\x4b9203cdfc252895172b602b096ab417a7c3004c",
                select: count("*")
        )

        Repo.one(query) 
        
    end
    
    
    def vanity_count() do
        query = from(l in "logs",
                where: l.address_hash == "\\x8cafc3eb956b95a3a0bccbc31cedd8042b2c45a8",
                select: count("*")
        )

        Repo.one(query)
    end

    def transaction_time() do
        query = from(l in "logs",
                where: l.address_hash == "\\x4b9203cdfc252895172b602b096ab417a7c3004c" or l.address_hash == "\\x8cafc3eb956b95a3a0bccbc31cedd8042b2c45a8",
                select: l.inserted_at,
                order_by: [desc: l.inserted_at],
                limit: 1
        )
        
       NaiveDateTime.diff(NaiveDateTime.utc_now ,Repo.one(query))/60
    end

    
end

 
