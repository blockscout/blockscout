# 


# API Documentation


# Group BlockScoutWeb.Account.Api.V1.AuthController
## BlockScoutWeb.Account.Api.V1.AuthController [/auth/auth0_api]
### BlockScoutWeb.Account.Api.V1.AuthController info [GET /auth/auth0_api]


 


+ Login
**GET**&nbsp;&nbsp;`/auth/auth0_api`

+ Response 200

    + Body
    
            {"auth_token":"..."}


# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/info]
### BlockScoutWeb.Account.Api.V1.UserController info [GET /api/account/v1/user/info]


 


+ Request Get info about user
**GET**&nbsp;&nbsp;`/api/account/v1/user/info`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYmU2NmU2M2QtMTg1Ni00NmQ0LWFlOWQtZDJlZmU1NDA3YzFiIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.w5XqRUEaoU-Do1xbJXzk_d6c_i178HKZGvXFjCnvVDl-xisfSmlPNa1CD9kodon31DAXJHmI7j3xzoRaiYSIhQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkfhTtn5F3UAAB4h
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "nickname": "test_user6",
              "name": "User Test6",
              "email": "test_user-6@blockscout.com",
              "avatar": "https://example.com/avatar/test_user6"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_tag_address [POST /api/account/v1/user/tags/address]


 


+ Request Add private address tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/address`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDMzNWQzZmMtZGMzMi00OTc4LWE2ZDAtZDk4OGEzNTkzY2Y4IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.9VI7ntjUUBlpl1IfZl811MXfK4Jy5JLEhVAdavwyU7mP2AH_m9PkE-kexCJ0zBpy697xmKmvG6tRzdPqsjFAiw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "MyName",
              "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlBizfokKFYAAAsD
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "MyName",
              "id": 4,
              "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
            }

# Group BlockScoutWeb.Account.Api.V1.TagsController
## BlockScoutWeb.Account.Api.V1.TagsController [/api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b]
### BlockScoutWeb.Account.Api.V1.TagsController tags_address [GET /api/account/v1/tags/address/{address_hash}]


 

+ Parameters
    + address_hash: `0x3e9ac8f16c92bc4f093357933b5befbf1e16987b`
            address_hash: 0x3e9ac8f16c92bc4f093357933b5befbf1e16987b


+ Request Get tags for address
**GET**&nbsp;&nbsp;`/api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDMzNWQzZmMtZGMzMi00OTc4LWE2ZDAtZDk4OGEzNTkzY2Y4IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.9VI7ntjUUBlpl1IfZl811MXfK4Jy5JLEhVAdavwyU7mP2AH_m9PkE-kexCJ0zBpy697xmKmvG6tRzdPqsjFAiw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlCcl8IkKFYAAAsj
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "watchlist_names": [],
              "personal_tags": [
                {
                  "label": "MyName",
                  "display_name": "MyName"
                }
              ],
              "common_tags": []
            }

# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/address]
### BlockScoutWeb.Account.Api.V1.UserController tags_address [GET /api/account/v1/user/tags/address]


 


+ Request Get private addresses tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/address`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjg1Yzk5OTYtNjExMy00MWVjLTg3NTQtZmE0NTFhMDUwNmQ2IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.AO1RGETROKOc01_d0yCL2ldVnZ5xVcI63y7iKqh_p5tVFDz8M6wsVChxpUh51GoloEkF_JTmV6rWkYWK5oWA_A

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkctJMfKv1MAAAgi
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "name": "name0",
                "id": 1,
                "address_hash": "0x0000000000000000000000000000000000000006"
              },
              {
                "name": "name1",
                "id": 2,
                "address_hash": "0x0000000000000000000000000000000000000007"
              },
              {
                "name": "name2",
                "id": 3,
                "address_hash": "0x0000000000000000000000000000000000000008"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_address [DELETE /api/account/v1/user/tags/address/{tag_id}]


 

+ Parameters
    + tag_id: `5`
            tag_id: 5


+ Request Delete private address tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/address/5`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiM2I5YTc5MDktNDM0Mi00ZmE1LTliODAtM2I1ZTEwMjRlMzY5IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.8UgJQkkWG48fKsOxxced0HI1vCC4se9gEnkliRSyntiftyOyU3a_nH7DH3ig_7KazaieyMiqIQ3g-HzuWfItBg

+ Response 200

    + Headers
    
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlP5aTkOKREAACIh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            
### BlockScoutWeb.Account.Api.V1.UserController create_tag_transaction [POST /api/account/v1/user/tags/transaction]


 


+ Request Create private transaction tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZmJkODBkNDktNmZjYi00MTliLWJmYzctYzMxOTc3NzNiMmY2IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.Ri_g5wvJAWse-HmQKDoF3qCnd1pYaCJ1ft06xLufye5xciO7rDGdUMgYd7m2v0N2YIrD-0ZJuFblil1150xM7w
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "MyName"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkujpg9dpkgAAAni
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "MyName",
              "id": 2
            }


+ Request Error on try to create private transaction tag for tx does not exist
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZmJkODBkNDktNmZjYi00MTliLWJmYzctYzMxOTc3NzNiMmY2IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.Ri_g5wvJAWse-HmQKDoF3qCnd1pYaCJ1ft06xLufye5xciO7rDGdUMgYd7m2v0N2YIrD-0ZJuFblil1150xM7w
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
              "name": "MyName"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkt6tJ1dpkgAAB8h
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "errors": {
                "tx_hash": [
                  "Transaction does not exist"
                ]
              }
            }

# Group BlockScoutWeb.Account.Api.V1.TagsController
## BlockScoutWeb.Account.Api.V1.TagsController [/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000001]
### BlockScoutWeb.Account.Api.V1.TagsController tags_transaction [GET /api/account/v1/tags/transaction/{transaction_hash}]


 

+ Parameters
    + transaction_hash: `0x0000000000000000000000000000000000000000000000000000000000000001`
            transaction_hash: 0x0000000000000000000000000000000000000000000000000000000000000001


+ Request Get tags for transaction
**GET**&nbsp;&nbsp;`/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000001`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZmJkODBkNDktNmZjYi00MTliLWJmYzctYzMxOTc3NzNiMmY2IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.Ri_g5wvJAWse-HmQKDoF3qCnd1pYaCJ1ft06xLufye5xciO7rDGdUMgYd7m2v0N2YIrD-0ZJuFblil1150xM7w

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxku3cr9dpkgAAB9B
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "watchlist_names": [],
              "personal_tx_tag": {
                "label": "MyName"
              },
              "personal_tags": [],
              "common_tags": []
            }

# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/transaction]
### BlockScoutWeb.Account.Api.V1.UserController tags_transaction [GET /api/account/v1/user/tags/transaction]


 


+ Request Get private transactions tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZGZmYmQ3YWQtMDU3Yy00YmIwLWE5OGMtZDU0NzdjYzE5ZjA1IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.77-CgmZCiey-rqbk2ZFDc6Zq1q5bViT3fdp-b-0dsxU-MVJvp8O1g9IOhM4oH101mKreUfV9kuUI-z7bN3rzAw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlr3MH60x0YAAA7i
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000005",
                "name": "name0",
                "id": 6
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000006",
                "name": "name1",
                "id": 7
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000007",
                "name": "name2",
                "id": 8
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_transaction [DELETE /api/account/v1/user/tags/transaction/{tag_id}]


 

+ Parameters
    + tag_id: `3`
            tag_id: 3


+ Request Delete private transaction tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/3`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYTI4NzI2YjYtY2VmOC00NzVmLWIxZDQtNDA4ODgzNTVjM2U3IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDExIiwidHlwIjoiYWNjZXNzIn0.6yZ1_GhjkK2l61meVx4W0mcl60FBXhP9Oa9UHNEYWgLCP_3B9mu5wxsA6QFpML_rXM_lzFrFH8PuADo6yqF-AQ

+ Response 200

    + Headers
    
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxk7jZNHVWZ8AAB_B
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Add address to watchlist
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYzA5ZmVmOWItNTI1ZS00ODVmLTg5NDYtOTA0MDAxNDA1YjMzIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.HP8O5RIC2p3qZFJXgetXtwvBkAtyWo0oBeSsGUdE0UFF6Lxb6bPrSUW2yhC0P6M08yhwhwrEPWIZIUSESza_xQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": true,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test1",
              "address_hash": "0x0000000000000000000000000000000000000002"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkF063gYvncAAAvk
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": true,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test1",
              "id": 1,
              "exchange_rate": null,
              "address_hash": "0x0000000000000000000000000000000000000002",
              "address_balance": null
            }
### BlockScoutWeb.Account.Api.V1.UserController watchlist [GET /api/account/v1/user/watchlist]


 


+ Request Get addresses from watchlists
**GET**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYzA5ZmVmOWItNTI1ZS00ODVmLTg5NDYtOTA0MDAxNDA1YjMzIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.HP8O5RIC2p3qZFJXgetXtwvBkAtyWo0oBeSsGUdE0UFF6Lxb6bPrSUW2yhC0P6M08yhwhwrEPWIZIUSESza_xQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkJ50yMYvncAAAyk
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "notification_settings": {
                  "native": {
                    "outcoming": true,
                    "incoming": false
                  },
                  "ERC-721": {
                    "outcoming": true,
                    "incoming": true
                  },
                  "ERC-20": {
                    "outcoming": true,
                    "incoming": true
                  }
                },
                "notification_methods": {
                  "email": false
                },
                "name": "test1",
                "id": 1,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000002",
                "address_balance": null
              },
              {
                "notification_settings": {
                  "native": {
                    "outcoming": true,
                    "incoming": false
                  },
                  "ERC-721": {
                    "outcoming": true,
                    "incoming": true
                  },
                  "ERC-20": {
                    "outcoming": true,
                    "incoming": false
                  }
                },
                "notification_methods": {
                  "email": false
                },
                "name": "test2",
                "id": 2,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000003",
                "address_balance": null
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_watchlist [DELETE /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `8`
            id: 8


+ Request Delete address from watchlist by id
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/watchlist/8`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNjE0YjE3NzgtNDEyOS00NTJlLWFhOGYtM2QyODY4NWYzNzEwIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.PJL5keGxdrsTg6FNJiTpJBibYuusYerVx-KLKYfvdcMxFqIx8hEYzz8v9vAfNdMw-GvWDHXjqhCBR9F8q2_awQ

+ Response 200

    + Headers
    
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlyDd-zc9_YAAA_i
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `6`
            id: 6


+ Request Edit watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/6`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNmFjZjBiMjAtOTZjMi00OTI0LWFmM2MtZjQ2MDliMzMyNzlkIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEzIiwidHlwIjoiYWNjZXNzIn0.BXUKhTMGqS_Vg00NTJWNFigISKBSY4cGheVe1k1MzZ9yAW-bDgF5zjXqWkw9Fdb6MdHgc-sQ9q2GJIrD7eCRtA
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test9",
              "address_hash": "0x0000000000000000000000000000000000000017"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlG1TwpQxv0AAAvC
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test9",
              "id": 6,
              "exchange_rate": null,
              "address_hash": "0x0000000000000000000000000000000000000017",
              "address_balance": null
            }
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Example of error on creating watchlist address
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDI1YjM4MDUtODViYS00Mzg4LThmMmMtMjhlN2RkYWYyZTJkIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.JFEKoQFAsVnOd_e2pdcgbtSP2r4r2lEOShhlljSz1gkWhEGIlaNs_TiMr1LNSdSuV_mO8sP_K5hhqK-ozY9DNg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": true,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test5",
              "address_hash": "0x0000000000000000000000000000000000000009"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkjI1gJcO10AAB5B
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "errors": {
                "watchlist_id": [
                  "Address already added to the watchlist"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `5`
            id: 5


+ Request Example of error on editing watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/5`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDI1YjM4MDUtODViYS00Mzg4LThmMmMtMjhlN2RkYWYyZTJkIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.JFEKoQFAsVnOd_e2pdcgbtSP2r4r2lEOShhlljSz1gkWhEGIlaNs_TiMr1LNSdSuV_mO8sP_K5hhqK-ozY9DNg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": true,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test5",
              "address_hash": "0x0000000000000000000000000000000000000009"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkkeeIhcO10AAB6B
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "errors": {
                "watchlist_id": [
                  "Address already added to the watchlist"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController create_api_key [POST /api/account/v1/user/api_keys]


 


+ Request Add api key
**POST**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjUwM2NlNTAtZjQ0MS00ZTlkLWJmMDAtNzcyNDQxYjhmZjU4IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDMiLCJ0eXAiOiJhY2Nlc3MifQ.9zV_BzXhw6QfQXfdoK0RbSpW30MjjNIEichwX5V9UmQgA9CiGkDypDkC99s5hw7c5qVMvT7HM78Cvb2eCyJU6A
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkRoxvsvBusAABwB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test",
              "api_key": "baca172d-7a4d-47c7-a873-a1caf0f7c9ec"
            }


+ Request Example of error on creating api key
**POST**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWQwZWU4YmYtN2UyZi00NWYyLWE1YTAtZTdiODc0ZDVmZGE1IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.L29RAPlqh_kyGacYADVd41W0JDCXtBA5U1-Vu-415NS19r7AJvHMeWXcHQLA1B6JxIeRqGNBbI2PkfACA-7UCQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkVYDOP534QAAB0h
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "errors": {
                "name": [
                  "Max 3 keys per account"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController api_keys [GET /api/account/v1/user/api_keys]


 


+ Request Get api keys list
**GET**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWQwZWU4YmYtN2UyZi00NWYyLWE1YTAtZTdiODc0ZDVmZGE1IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.L29RAPlqh_kyGacYADVd41W0JDCXtBA5U1-Vu-415NS19r7AJvHMeWXcHQLA1B6JxIeRqGNBbI2PkfACA-7UCQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkVl7uz534QAAAij
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "name": "test",
                "api_key": "03fb2b1f-d76b-4e7c-8b1c-4b5511a85f8f"
              },
              {
                "name": "test",
                "api_key": "8f4a4609-e003-44f9-85c2-8f4d157ef4fa"
              },
              {
                "name": "test",
                "api_key": "728ad21f-8ef1-4e48-adb5-d632c7476767"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController update_api_key [PUT /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `034db3b6-7d4e-40e1-8ba0-e5ca985a90fd`
            api_key: 034db3b6-7d4e-40e1-8ba0-e5ca985a90fd


+ Request Edit api key
**PUT**&nbsp;&nbsp;`/api/account/v1/user/api_keys/034db3b6-7d4e-40e1-8ba0-e5ca985a90fd`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOWM2MjdkNGEtYTE2YS00YTNjLThmMGEtMDg2ZWVjYzQ4YjU2IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE2IiwidHlwIjoiYWNjZXNzIn0.DkuS5AZxsMf9zcjMtpFO4oZbTRM_o38XvOa3lylwZZUMg4YO5kA8KmSLBnTy5J8chVEhTX3XSaDu9BUjg0BKpw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test_1"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxliKUHvTKa0AACSB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test_1",
              "api_key": "034db3b6-7d4e-40e1-8ba0-e5ca985a90fd"
            }
### BlockScoutWeb.Account.Api.V1.UserController delete_api_key [DELETE /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `b2b59085-03d1-4d74-8510-c0164b47b309`
            api_key: b2b59085-03d1-4d74-8510-c0164b47b309


+ Request Delete api key
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/api_keys/b2b59085-03d1-4d74-8510-c0164b47b309`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMjZjZjE3ODItYWY1ZS00MmM1LTg3OTQtMWVlZGIyOTYyYzRlIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.juQufHG6gUtWE5_Pn3az1zH3QBr-wNo3vbfuutDThyBA17djQP10X8KfgduZ4VGBcD2rGU_qjVgTI5PDVD2t5Q

+ Response 200

    + Headers
    
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkrsuxMYB_0AAAmi
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            
### BlockScoutWeb.Account.Api.V1.UserController create_custom_abi [POST /api/account/v1/user/custom_abis]


 


+ Request Add custom abi
**POST**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDBjMTFmZDAtMjE1MS00ZjVmLWIyYTgtZDY0MjA1MjBiZTg3IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.dwG3X_T52ylcbo0Na06EmAbUPG51ylD_P6X-YCaRK9kkjmK1RdRKCzEtlI_uQWZoIDLBQg3-5HE91Pk94jIGgQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test7",
              "contract_address_hash": "0x000000000000000000000000000000000000000b",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxknhFQIVEecAAB7B
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test7",
              "id": 3,
              "contract_address_hash": "0x000000000000000000000000000000000000000b",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }


+ Request Example of error on creating custom abi
**POST**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZTg2MzIzZDAtZjA2MS00ZDBjLWFkMGMtMzcxZmFiYzdlMzhlIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.cHdSjNMlPSIPNVVjhpM85BOWszyUB7JVcRRYi6_YKxaVaim1HRmZ-fmHG3XDwmKwpwwCBJ5Yor-_jxC_CzBXhQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test25",
              "contract_address_hash": "0x000000000000000000000000000000000000002a",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlgUPCFGZ8sAAA2C
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "errors": {
                "name": [
                  "Max 15 ABIs per account"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController custom_abis [GET /api/account/v1/user/custom_abis]


 


+ Request Get custom abis list
**GET**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZTg2MzIzZDAtZjA2MS00ZDBjLWFkMGMtMzcxZmFiYzdlMzhlIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.cHdSjNMlPSIPNVVjhpM85BOWszyUB7JVcRRYi6_YKxaVaim1HRmZ-fmHG3XDwmKwpwwCBJ5Yor-_jxC_CzBXhQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxlgpJ8NGZ8sAAA2i
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "name": "test10",
                "id": 4,
                "contract_address_hash": "0x000000000000000000000000000000000000001b",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test11",
                "id": 5,
                "contract_address_hash": "0x000000000000000000000000000000000000001c",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test12",
                "id": 6,
                "contract_address_hash": "0x000000000000000000000000000000000000001d",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test13",
                "id": 7,
                "contract_address_hash": "0x000000000000000000000000000000000000001e",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test14",
                "id": 8,
                "contract_address_hash": "0x000000000000000000000000000000000000001f",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test15",
                "id": 9,
                "contract_address_hash": "0x0000000000000000000000000000000000000020",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test16",
                "id": 10,
                "contract_address_hash": "0x0000000000000000000000000000000000000021",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test17",
                "id": 11,
                "contract_address_hash": "0x0000000000000000000000000000000000000022",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test18",
                "id": 12,
                "contract_address_hash": "0x0000000000000000000000000000000000000023",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test19",
                "id": 13,
                "contract_address_hash": "0x0000000000000000000000000000000000000024",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test20",
                "id": 14,
                "contract_address_hash": "0x0000000000000000000000000000000000000025",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test21",
                "id": 15,
                "contract_address_hash": "0x0000000000000000000000000000000000000026",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test22",
                "id": 16,
                "contract_address_hash": "0x0000000000000000000000000000000000000027",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test23",
                "id": 17,
                "contract_address_hash": "0x0000000000000000000000000000000000000028",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              },
              {
                "name": "test24",
                "id": 18,
                "contract_address_hash": "0x0000000000000000000000000000000000000029",
                "abi": [
                  {
                    "type": "function",
                    "stateMutability": "nonpayable",
                    "payable": false,
                    "outputs": [],
                    "name": "set",
                    "inputs": [
                      {
                        "type": "uint256",
                        "name": "x"
                      }
                    ],
                    "constant": false
                  },
                  {
                    "type": "function",
                    "stateMutability": "view",
                    "payable": false,
                    "outputs": [
                      {
                        "type": "uint256",
                        "name": ""
                      }
                    ],
                    "name": "get",
                    "inputs": [],
                    "constant": true
                  }
                ]
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController update_custom_abi [PUT /api/account/v1/user/custom_abis/{id}]


 

+ Parameters
    + id: `2`
            id: 2


+ Request Edit custom abi
**PUT**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/2`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMTVkMDcyMTAtOGQxOC00NzM2LTgxYzEtYWYzNGMyOTQ2ZWNiIiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIiLCJ0eXAiOiJhY2Nlc3MifQ.Qpu0OMP4KT9Ws0TbXKXJI9L7lR5P_mblL4uHgqKDeX4L6AtWlGn78EHAfEvTSKiLwRPXRHtyEW3xNIk4b7tqTA
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test4",
              "contract_address_hash": "0x0000000000000000000000000000000000000005",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkOxwco91CwAAA2k
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test4",
              "id": 2,
              "contract_address_hash": "0x0000000000000000000000000000000000000005",
              "abi": [
                {
                  "type": "function",
                  "stateMutability": "nonpayable",
                  "payable": false,
                  "outputs": [],
                  "name": "set",
                  "inputs": [
                    {
                      "type": "uint256",
                      "name": "x"
                    }
                  ],
                  "constant": false
                },
                {
                  "type": "function",
                  "stateMutability": "view",
                  "payable": false,
                  "outputs": [
                    {
                      "type": "uint256",
                      "name": ""
                    }
                  ],
                  "name": "get",
                  "inputs": [],
                  "constant": true
                }
              ]
            }
### BlockScoutWeb.Account.Api.V1.UserController delete_custom_abi [DELETE /api/account/v1/user/custom_abis/{id}]


 

+ Parameters
    + id: `1`
            id: 1


+ Request Delete custom abi
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/1`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjAwMzcxODQsImlhdCI6MTY1NzYxNzk4NCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMzE3NzUxM2MtNGNjMC00YTNjLWJhMDgtN2M0MjM4ZGQwMDg1IiwibmJmIjoxNjU3NjE3OTgzLCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.V0AAIxJ-M5zdpYJUvXMeMn_PW5Ij77bN8nFvieJSTVBZFugzkXFFQwOE1ancCIlDZjZwYKgJzOtYKtCKx6pzNA

+ Response 200

    + Headers
    
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwEKxkB655DsLCoAAAsE
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            

