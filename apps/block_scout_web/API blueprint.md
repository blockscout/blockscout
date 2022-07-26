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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNDI5NDBiMGUtY2I1Ny00YzQ5LWJjMmUtMTIxZjBmZGNkMGIzIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE5IiwidHlwIjoiYWNjZXNzIn0.1v4u5r5o0f8FBGr4eZ0U3_rF9hJmL8PxNnDZLMxi6EtO6SlmM5FiUdC0AmPYjdMhOSvrTF-hJUHy6u3PztMNUQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9OSIm67azAAABJB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "nickname": "test_user19",
              "name": "User Test19",
              "email": "test_user-19@blockscout.com",
              "avatar": "https://example.com/avatar/test_user19"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_tag_address [POST /api/account/v1/user/tags/address]


 


+ Request Add private address tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/address`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMGRkMWFhNmQtNTNlYy00ODUwLTlhNjMtYTQ0ZDEzMzI4NzYxIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.Y358pcM31Tr8trpa-YQ4Gw7V-o8MafjUtrWcIvPvQpg-N50uxCWfuJ82mp6tAtuPzaSY_r2-YqZnUavQdm3Pvw
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
            x-request-id: FwX9H8nMFI1lqPkAAAuh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "MyName",
              "id": 127,
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMGRkMWFhNmQtNTNlYy00ODUwLTlhNjMtYTQ0ZDEzMzI4NzYxIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.Y358pcM31Tr8trpa-YQ4Gw7V-o8MafjUtrWcIvPvQpg-N50uxCWfuJ82mp6tAtuPzaSY_r2-YqZnUavQdm3Pvw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8oI7GZlqPkAAAvB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "watchlist_names": [],
              "personal_tags": [
                {
                  "label": "MyName",
                  "display_name": "MyName",
                  "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
                }
              ],
              "common_tags": []
            }

# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/address/128]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_address [PUT /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `128`
            id: 128


+ Request Edit private address tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/address/128`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMGQxNTAyMTAtYjMxNy00MjgzLWI0NjAtZDIzNmQ2MGZkMzlmIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIwIiwidHlwIjoiYWNjZXNzIn0.JdHdw1NwwHTzZqCZ0WjiMG6gnTOVspvXFL7M9FhSkJiwLvmyhcBxo410Z3MlqqKEnuP93nQua6i6AIynuHr2Kw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "name3",
              "address_hash": "0x000000000000000000000000000000000000002f"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9P_gHp-3AQAABMh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "name3",
              "id": 128,
              "address_hash": "0x000000000000000000000000000000000000002f"
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_address [GET /api/account/v1/user/tags/address]


 


+ Request Get private addresses tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/address`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMjVmZTUyNWMtNGIzNi00NDJjLWEwM2QtOGM2MTgwOWEyOTdkIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.lbGj3MpBlPgOwlfoaIWqzsQrFz8XhGZAwFJNd7b5xrdEjhehdQNCCsLyAdr3OOenldwsXHKefkcsMtPrllbwfw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8a8MMUw_lsAAAah
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "name": "name0",
                "id": 124,
                "address_hash": "0x0000000000000000000000000000000000000003"
              },
              {
                "name": "name1",
                "id": 125,
                "address_hash": "0x0000000000000000000000000000000000000004"
              },
              {
                "name": "name2",
                "id": 126,
                "address_hash": "0x0000000000000000000000000000000000000005"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_address [DELETE /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `129`
            id: 129


+ Request Delete private address tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/address/129`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDBkNGU0N2UtYzE3OS00OWFjLThlMzQtZWJjNmMwZWYyYWZhIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIzIiwidHlwIjoiYWNjZXNzIn0.EFn5CLnK97TZjHHdyqZfboDWuSRvgmaBZQSe9TgPejixPrg_dMRIOpXiGNkM64flduFmSGKcsmLYKSaZ-LHO0Q

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9f16PR-c2IAAAuC
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_tag_transaction [POST /api/account/v1/user/tags/transaction]


 


+ Request Create private transaction tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTc0NzA5ODktN2MxYi00MjBlLTk0YzQtMDQ5NjZlYzdjZDM3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.7qv6zbqlLEWzwpztNfXshGLDHLL95FOghZIu_9Cl_lj7_mYkEjbky14RI0Ro5Y0cK817FmPq0CSYX-ZCxmpESg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
              "name": "MyName"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9FrA4SXFKIAAAYi
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
              "name": "MyName",
              "id": 149
            }


+ Request Error on try to create private transaction tag for tx does not exist
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTc0NzA5ODktN2MxYi00MjBlLTk0YzQtMDQ5NjZlYzdjZDM3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.7qv6zbqlLEWzwpztNfXshGLDHLL95FOghZIu_9Cl_lj7_mYkEjbky14RI0Ro5Y0cK817FmPq0CSYX-ZCxmpESg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000008",
              "name": "MyName"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9EuXVCXFKIAAA-B
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
## BlockScoutWeb.Account.Api.V1.TagsController [/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000009]
### BlockScoutWeb.Account.Api.V1.TagsController tags_transaction [GET /api/account/v1/tags/transaction/{transaction_hash}]


 

+ Parameters
    + transaction_hash: `0x0000000000000000000000000000000000000000000000000000000000000009`
            transaction_hash: 0x0000000000000000000000000000000000000000000000000000000000000009


+ Request Get tags for transaction
**GET**&nbsp;&nbsp;`/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000009`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTc0NzA5ODktN2MxYi00MjBlLTk0YzQtMDQ5NjZlYzdjZDM3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.7qv6zbqlLEWzwpztNfXshGLDHLL95FOghZIu_9Cl_lj7_mYkEjbky14RI0Ro5Y0cK817FmPq0CSYX-ZCxmpESg

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9F50_-XFKIAAA-h
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
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/transaction/144]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_transaction [PUT /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `144`
            id: 144


+ Request Edit private transaction tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/144`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMTBhMGYyYTItNzc3MC00Y2Y2LTgxMzgtNDcwZjI2ZmNhOWZiIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDExIiwidHlwIjoiYWNjZXNzIn0.IxHBdrhZjcVbN9DKUBAcxdlL8UJDqK-4Vcu5vTbmnvZPgqYuRfqMlkDDL6z9Uvs613_7bAWXP1QLFJB3k0JdSQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000004",
              "name": "name1"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H85G2H7pPTUAAAQi
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000004",
              "name": "name1",
              "id": 144
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_transaction [GET /api/account/v1/user/tags/transaction]


 


+ Request Get private transactions tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWVkMjFiNGEtZGVlZC00NzMzLWJhNWQtZWZhMzc4MWQ0Y2JmIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.IZ0bV7ZpzlQLrWcvuDI5gLkiHO4Tlb4gHWYp0BPko67c65i1Go4CGQla48PGrV4tmAtB52No9EJOPIx5BFi3HA

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8vIbEt0TAgAAAiD
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
                "name": "name0",
                "id": 141
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
                "name": "name1",
                "id": 142
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000002",
                "name": "name2",
                "id": 143
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_transaction [DELETE /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `145`
            id: 145


+ Request Delete private transaction tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/145`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOWMzMmNhMDYtZWQ1MS00N2FkLThhOGUtNjQ3ZDQ1YjA2Yzc1IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.zoyPtivvXWSp-bmco0TZk23SaEDkExrePwwUELiJmpLROmayNTbAat2iWPwjS5aoi4vrJ5i3TovSnkgyto2FPw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8_XjGhcVs8AAAUC
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Add address to watchlist
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiY2JkNThlMmYtNTlmNy00MWMxLTgzNGQtYzZhNzg1NWFhNTMwIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIxIiwidHlwIjoiYWNjZXNzIn0.ugSCWLPiRXd8nrldXQae9s-O93Y9jMyGSrqAIVNycbE303ws06ZJC4OELTs3z5qJE4Vu2gT430f7JU9diO4hwQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test10",
              "address_hash": "0x0000000000000000000000000000000000000030"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9RGF0el_skAAAhi
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-721": {
                  "outcoming": true,
                  "incoming": false
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test10",
              "id": 143,
              "exchange_rate": null,
              "address_hash": "0x0000000000000000000000000000000000000030",
              "address_balance": null
            }
### BlockScoutWeb.Account.Api.V1.UserController watchlist [GET /api/account/v1/user/watchlist]


 


+ Request Get addresses from watchlists
**GET**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiY2JkNThlMmYtNTlmNy00MWMxLTgzNGQtYzZhNzg1NWFhNTMwIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIxIiwidHlwIjoiYWNjZXNzIn0.ugSCWLPiRXd8nrldXQae9s-O93Y9jMyGSrqAIVNycbE303ws06ZJC4OELTs3z5qJE4Vu2gT430f7JU9diO4hwQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9TRT0Cl_skAAAjC
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "notification_settings": {
                  "native": {
                    "outcoming": false,
                    "incoming": true
                  },
                  "ERC-721": {
                    "outcoming": true,
                    "incoming": false
                  },
                  "ERC-20": {
                    "outcoming": false,
                    "incoming": false
                  }
                },
                "notification_methods": {
                  "email": true
                },
                "name": "test10",
                "id": 143,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000030",
                "address_balance": null
              },
              {
                "notification_settings": {
                  "native": {
                    "outcoming": false,
                    "incoming": true
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
                "name": "test11",
                "id": 144,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000031",
                "address_balance": null
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_watchlist [DELETE /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `141`
            id: 141


+ Request Delete address from watchlist by id
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/watchlist/141`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOTBjOTk3NWMtMmFlNC00ZjA2LWJmOTktYjZhNGM3NzAxMTgyIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDMiLCJ0eXAiOiJhY2Nlc3MifQ.0L0xwmjeU1spzJuJpHXOhOhmdui3ftU14ALdGsVdevRg2HLdjY34XTgdfS6oDquXOT3DXJmKwUYOQL2YVXT5zw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8iY6XaB5iEAAAmh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `142`
            id: 142


+ Request Edit watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/142`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMGU2NDNjZDYtZWY3NC00ZjNlLWJkM2QtMmRkMzQ3YzViMWYwIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.2C8xUsb-p8dJlgvKFBW8EGIwXDRNkAOG5Mi-1iWogolLpVqmgCkVgS-UknGNb2IfPChRhI9J5AqF_pQ9QVZoHw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test9",
              "address_hash": "0x000000000000000000000000000000000000002d"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9LfJ0ItKUsAABFh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": true
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": true
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": true
                }
              },
              "notification_methods": {
                "email": true
              },
              "name": "test9",
              "id": 142,
              "exchange_rate": null,
              "address_hash": "0x000000000000000000000000000000000000002d",
              "address_balance": null
            }
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Example of error on creating watchlist address
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYTY2M2JlNzMtOTFjMy00ZWRjLWE2YmQtMWJjOGE1MmM4NTk3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.zFABFWiAkeaeXzDL2Oc_DjwxYEq0ZfZCjUemzPIfgU5S3rpw2kZKRhWhpGPAB9NbeX2LEiX71nvPd6Kr1ZqkTw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": true
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
                "email": true
              },
              "name": "test0",
              "address_hash": "0x0000000000000000000000000000000000000001"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8TH4IeSrmsAAATh
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
    + id: `139`
            id: 139


+ Request Example of error on editing watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/139`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYTY2M2JlNzMtOTFjMy00ZWRjLWE2YmQtMWJjOGE1MmM4NTk3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.zFABFWiAkeaeXzDL2Oc_DjwxYEq0ZfZCjUemzPIfgU5S3rpw2kZKRhWhpGPAB9NbeX2LEiX71nvPd6Kr1ZqkTw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
                  "incoming": true
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
                "email": true
              },
              "name": "test0",
              "address_hash": "0x0000000000000000000000000000000000000001"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8U3jEKSrmsAAAUh
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNzFjYmRkNWMtMDBiZC00MjY4LTliNmYtZDc1MDhlOWI2YjcxIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.V0HIqp8ynSybsSfvdHpkywR4rgszPMpUKXrHNz1RfW1QibT-lJDtE0YGB_SWcClQPlTPB8kF2vOXgnuqm2dc8A
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8yY1najgTYAAAxh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test",
              "api_key": "ca9398ae-224c-4935-8e51-975c0e646487"
            }


+ Request Example of error on creating api key
**POST**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZGJiYjZhMDItZTE4YS00YjU4LWFlODItZGZhMTIxZTUyOTZmIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.vcwFRHpmSCegFqYEpJmxc7TS11f8gZgIbDZZj3S9UmXYdOkqs3RC6J6X0tz0C8hVhkz9ttA9wW1R6uwekFkQhA
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9Ics3lTy1EAABCh
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZGJiYjZhMDItZTE4YS00YjU4LWFlODItZGZhMTIxZTUyOTZmIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.vcwFRHpmSCegFqYEpJmxc7TS11f8gZgIbDZZj3S9UmXYdOkqs3RC6J6X0tz0C8hVhkz9ttA9wW1R6uwekFkQhA

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9IonHZTy1EAAAZC
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "name": "test",
                "api_key": "3ebadf72-dbbf-4f13-8480-0461f69de56d"
              },
              {
                "name": "test",
                "api_key": "e12f940b-4387-487b-b4c1-fbea90892fd9"
              },
              {
                "name": "test",
                "api_key": "5aef562b-6849-4e9e-93bd-6ad6c9aef33f"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController update_api_key [PUT /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `6b315305-56ef-441a-9d2e-ff4e6451c095`
            api_key: 6b315305-56ef-441a-9d2e-ff4e6451c095


+ Request Edit api key
**PUT**&nbsp;&nbsp;`/api/account/v1/user/api_keys/6b315305-56ef-441a-9d2e-ff4e6451c095`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjBiNDFjZTItMDQzZS00M2VjLTk5OWUtY2I5ZWU0ZmM1Y2Q0IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.ICMIz3WqHqn1ZhaSrBOp9y4ZyK4rzfArPGlyYcaP4dcKDVkCXE-QIp7bQivHmnfbiCW3JecHllxHanWl23RWwg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test_1"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9NExhFvvqoAABHh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test_1",
              "api_key": "6b315305-56ef-441a-9d2e-ff4e6451c095"
            }
### BlockScoutWeb.Account.Api.V1.UserController delete_api_key [DELETE /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `2cfe3ea9-0608-4086-9d51-a053166e2fb4`
            api_key: 2cfe3ea9-0608-4086-9d51-a053166e2fb4


+ Request Delete api key
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/api_keys/2cfe3ea9-0608-4086-9d51-a053166e2fb4`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMDYxOTg4MTQtOTc4Ny00MTY1LWE2ZjYtMTc5MzI0N2QzMDI5IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEzIiwidHlwIjoiYWNjZXNzIn0.hi7Xo5QAmbXBm-uFt3AgfyB8AzVicdNT1DkOMNVFhFHuLw3RfxP9hslNp97TL7wTR1dMIb8vaf9xjiKAlrnzvQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9DOzZvGWf4AAAXC
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_custom_abi [POST /api/account/v1/user/custom_abis]


 


+ Request Add custom abi
**POST**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODNiY2Q3NDMtNzU5Ni00OGUzLTg3Y2YtZTFmY2E4YWZmNTUzIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.dxOxJcXiSioauyKGh8WQBSuLd3XOpWUOf2M5cBmNQM81i6u9GEpMLCcVJ0So308PWE3Np7GGUCjQEZtb0YaWnw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test7",
              "contract_address_hash": "0x0000000000000000000000000000000000000016",
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
            x-request-id: FwX9H8119RH5E60AAA0B
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test7",
              "id": 309,
              "contract_address_hash": "0x0000000000000000000000000000000000000016",
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODczYzM2NjktY2JlZS00YWFiLTllNTAtZjgyYjAyODJlNDQxIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDI0IiwidHlwIjoiYWNjZXNzIn0.p0a8FOIu6VV7QAwtiERZ5WanI42oz8GkyoU3Tz0mz8kQlTpH1mZZgsPWb__epnNm61_rhHaelYLug0OtTvTRag
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test27",
              "contract_address_hash": "0x0000000000000000000000000000000000000078",
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
            x-request-id: FwX9H9pawu1W-8kAAAyC
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODczYzM2NjktY2JlZS00YWFiLTllNTAtZjgyYjAyODJlNDQxIiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDI0IiwidHlwIjoiYWNjZXNzIn0.p0a8FOIu6VV7QAwtiERZ5WanI42oz8GkyoU3Tz0mz8kQlTpH1mZZgsPWb__epnNm61_rhHaelYLug0OtTvTRag

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9ptd6pW-8kAAAxj
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "name": "test12",
                "id": 310,
                "contract_address_hash": "0x0000000000000000000000000000000000000069",
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
                "id": 311,
                "contract_address_hash": "0x000000000000000000000000000000000000006a",
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
                "id": 312,
                "contract_address_hash": "0x000000000000000000000000000000000000006b",
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
                "id": 313,
                "contract_address_hash": "0x000000000000000000000000000000000000006c",
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
                "id": 314,
                "contract_address_hash": "0x000000000000000000000000000000000000006d",
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
                "id": 315,
                "contract_address_hash": "0x000000000000000000000000000000000000006e",
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
                "id": 316,
                "contract_address_hash": "0x000000000000000000000000000000000000006f",
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
                "id": 317,
                "contract_address_hash": "0x0000000000000000000000000000000000000070",
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
                "id": 318,
                "contract_address_hash": "0x0000000000000000000000000000000000000071",
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
                "id": 319,
                "contract_address_hash": "0x0000000000000000000000000000000000000072",
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
                "id": 320,
                "contract_address_hash": "0x0000000000000000000000000000000000000073",
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
                "id": 321,
                "contract_address_hash": "0x0000000000000000000000000000000000000074",
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
                "id": 322,
                "contract_address_hash": "0x0000000000000000000000000000000000000075",
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
                "name": "test25",
                "id": 323,
                "contract_address_hash": "0x0000000000000000000000000000000000000076",
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
                "name": "test26",
                "id": 324,
                "contract_address_hash": "0x0000000000000000000000000000000000000077",
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
    + id: `308`
            id: 308


+ Request Edit custom abi
**PUT**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/308`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTc2ZWEzNWItMGQ1Ni00MTAzLTg1ODQtMjcyOGRhZjUxYTI4IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.NzbgShjGRIfZ6-HC7lXBJm602CqznDDRgxyTXZa-Kdkx2XTYErC93KBcZKgyZ7lo7u5olkavIEOnoxXc65sOxg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test6",
              "contract_address_hash": "0x000000000000000000000000000000000000000a",
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
            x-request-id: FwX9H8lVhnTsvpkAAArB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "name": "test6",
              "id": 308,
              "contract_address_hash": "0x000000000000000000000000000000000000000a",
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
    + id: `307`
            id: 307


+ Request Delete custom abi
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/307`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiY2YxODg0ODAtZGQ3My00ZDNmLTg2NDYtOTc2ZTRjMDJkMmE4IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIiLCJ0eXAiOiJhY2Nlc3MifQ.U23Zp-kENBQofisxQVrVAB9-JpBriWlxXJ9HZi_z9h_SV6psP6LhO0cLfnQsQkNWUOoO1LPQiWqVzP-zpGb7Sw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H8dnChNmonIAAAgB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_public_tags_request [POST /api/account/v1/user/public_tags]


 


+ Request Submit request to add a public tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/public_tags`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMmY2ZTM4N2QtMmI0ZC00Mjk4LWI5OWQtY2ZiYzMwOWU1NzM0IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE2IiwidHlwIjoiYWNjZXNzIn0.iLsnG2BBUIU3ENtV4GpDU82fThV3gcD-HJL1SGFM7C0n7cM7l09V4Mu6493ZpzjWBBnom8xexPH99kTvo_-aQg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "website": "website3",
              "tags": "Tag4;Tag5",
              "is_owner": false,
              "full_name": "full name3",
              "email": "email3",
              "company": "company3",
              "addresses_array": [
                "0x0000000000000000000000000000000000000025",
                "0x0000000000000000000000000000000000000026",
                "0x0000000000000000000000000000000000000027",
                "0x0000000000000000000000000000000000000028",
                "0x0000000000000000000000000000000000000029",
                "0x000000000000000000000000000000000000002a",
                "0x000000000000000000000000000000000000002b"
              ],
              "additional_comment": "additional_comment3"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9JM-GieXwUAABEB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "website": "website3",
              "tags": "Tag4;Tag5",
              "is_owner": false,
              "id": 99,
              "full_name": "full name3",
              "email": "email3",
              "company": "company3",
              "addresses": "0x0000000000000000000000000000000000000025;0x0000000000000000000000000000000000000026;0x0000000000000000000000000000000000000027;0x0000000000000000000000000000000000000028;0x0000000000000000000000000000000000000029;0x000000000000000000000000000000000000002a;0x000000000000000000000000000000000000002b",
              "additional_comment": "additional_comment3"
            }
### BlockScoutWeb.Account.Api.V1.UserController public_tags_requests [GET /api/account/v1/user/public_tags]


 


+ Request Get list of requests to add a public tag
**GET**&nbsp;&nbsp;`/api/account/v1/user/public_tags`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiN2ZlZjQ1MDMtMjk0My00NGJmLTk1MWItMGUxMjY2M2ZlZTg3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIyIiwidHlwIjoiYWNjZXNzIn0.AYEifMqZAXmZINrKt5pNtno7rb7UH32vsADul_Sgslt-kKIiiMiVzdAe7BeCOBMecr1L8j4KMRNl-qi4Deipwg

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9X-t7yrO6UAABRh
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            [
              {
                "website": "website4",
                "tags": "Tag6;Tag7",
                "is_owner": false,
                "id": 100,
                "full_name": "full name4",
                "email": "email4",
                "company": "company4",
                "addresses": "0x0000000000000000000000000000000000000032;0x0000000000000000000000000000000000000033;0x0000000000000000000000000000000000000034;0x0000000000000000000000000000000000000035;0x0000000000000000000000000000000000000036;0x0000000000000000000000000000000000000037",
                "additional_comment": "additional_comment4"
              },
              {
                "website": "website5",
                "tags": "Tag8;Tag9",
                "is_owner": false,
                "id": 101,
                "full_name": "full name5",
                "email": "email5",
                "company": "company5",
                "addresses": "0x0000000000000000000000000000000000000038",
                "additional_comment": "additional_comment5"
              },
              {
                "website": "website6",
                "tags": "Tag10",
                "is_owner": false,
                "id": 102,
                "full_name": "full name6",
                "email": "email6",
                "company": "company6",
                "addresses": "0x0000000000000000000000000000000000000039;0x000000000000000000000000000000000000003a;0x000000000000000000000000000000000000003b;0x000000000000000000000000000000000000003c;0x000000000000000000000000000000000000003d;0x000000000000000000000000000000000000003e;0x000000000000000000000000000000000000003f;0x0000000000000000000000000000000000000040;0x0000000000000000000000000000000000000041;0x0000000000000000000000000000000000000042",
                "additional_comment": "additional_comment6"
              },
              {
                "website": "website7",
                "tags": "Tag11",
                "is_owner": false,
                "id": 103,
                "full_name": "full name7",
                "email": "email7",
                "company": "company7",
                "addresses": "0x0000000000000000000000000000000000000043;0x0000000000000000000000000000000000000044;0x0000000000000000000000000000000000000045;0x0000000000000000000000000000000000000046;0x0000000000000000000000000000000000000047;0x0000000000000000000000000000000000000048",
                "additional_comment": "additional_comment7"
              },
              {
                "website": "website8",
                "tags": "Tag12;Tag13",
                "is_owner": false,
                "id": 104,
                "full_name": "full name8",
                "email": "email8",
                "company": "company8",
                "addresses": "0x0000000000000000000000000000000000000049;0x000000000000000000000000000000000000004a;0x000000000000000000000000000000000000004b;0x000000000000000000000000000000000000004c;0x000000000000000000000000000000000000004d",
                "additional_comment": "additional_comment8"
              },
              {
                "website": "website9",
                "tags": "Tag14",
                "is_owner": true,
                "id": 105,
                "full_name": "full name9",
                "email": "email9",
                "company": "company9",
                "addresses": "0x000000000000000000000000000000000000004e;0x000000000000000000000000000000000000004f;0x0000000000000000000000000000000000000050",
                "additional_comment": "additional_comment9"
              },
              {
                "website": "website10",
                "tags": "Tag15",
                "is_owner": true,
                "id": 106,
                "full_name": "full name10",
                "email": "email10",
                "company": "company10",
                "addresses": "0x0000000000000000000000000000000000000051;0x0000000000000000000000000000000000000052",
                "additional_comment": "additional_comment10"
              },
              {
                "website": "website11",
                "tags": "Tag16",
                "is_owner": true,
                "id": 107,
                "full_name": "full name11",
                "email": "email11",
                "company": "company11",
                "addresses": "0x0000000000000000000000000000000000000053;0x0000000000000000000000000000000000000054;0x0000000000000000000000000000000000000055;0x0000000000000000000000000000000000000056;0x0000000000000000000000000000000000000057;0x0000000000000000000000000000000000000058;0x0000000000000000000000000000000000000059;0x000000000000000000000000000000000000005a;0x000000000000000000000000000000000000005b;0x000000000000000000000000000000000000005c",
                "additional_comment": "additional_comment11"
              },
              {
                "website": "website12",
                "tags": "Tag17;Tag18",
                "is_owner": true,
                "id": 108,
                "full_name": "full name12",
                "email": "email12",
                "company": "company12",
                "addresses": "0x000000000000000000000000000000000000005d;0x000000000000000000000000000000000000005e;0x000000000000000000000000000000000000005f;0x0000000000000000000000000000000000000060",
                "additional_comment": "additional_comment12"
              },
              {
                "website": "website13",
                "tags": "Tag19",
                "is_owner": false,
                "id": 109,
                "full_name": "full name13",
                "email": "email13",
                "company": "company13",
                "addresses": "0x0000000000000000000000000000000000000061;0x0000000000000000000000000000000000000062;0x0000000000000000000000000000000000000063;0x0000000000000000000000000000000000000064;0x0000000000000000000000000000000000000065",
                "additional_comment": "additional_comment13"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_public_tags_request [DELETE /api/account/v1/user/public_tags/{id}]


 

+ Parameters
    + id: `100`
            id: 100


+ Request Delete public tags request
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/public_tags/100`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiN2ZlZjQ1MDMtMjk0My00NGJmLTk1MWItMGUxMjY2M2ZlZTg3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIyIiwidHlwIjoiYWNjZXNzIn0.AYEifMqZAXmZINrKt5pNtno7rb7UH32vsADul_Sgslt-kKIiiMiVzdAe7BeCOBMecr1L8j4KMRNl-qi4Deipwg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "remove_reason": "reason"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H9YQm9CrO6UAABSB
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController update_public_tags_request [PUT /api/account/v1/user/public_tags/{id}]


 

+ Parameters
    + id: `98`
            id: 98


+ Request Edit request to add a public tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/public_tags/98`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1NTAsImlhdCI6MTY1OTAxMDM1MCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODIxNWFhMjQtZWIzYS00MjhhLTlkZWMtNTQwMjkwZWExM2E3IiwibmJmIjoxNjU5MDEwMzQ5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.xY6RWMzDzBNhZpdrA6-sJ41xWnSM8n_uxmlbWxcBVXdIG6NJJi-_1ZARRmPdtquK0eosX81Q_OvML2NTp684kQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "website": "website2",
              "tags": "Tag3",
              "is_owner": true,
              "full_name": "full name2",
              "email": "email2",
              "company": "company2",
              "addresses_array": [
                "0x0000000000000000000000000000000000000015"
              ],
              "additional_comment": "additional_comment2"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwX9H80jCquTUzMAAAKC
            access-control-allow-origin: *
            access-control-expose-headers: 
            access-control-allow-credentials: true
    + Body
    
            {
              "website": "website2",
              "tags": "Tag3",
              "is_owner": true,
              "id": 98,
              "full_name": "full name2",
              "email": "email2",
              "company": "company2",
              "addresses": "0x0000000000000000000000000000000000000015",
              "additional_comment": "additional_comment2"
            }

