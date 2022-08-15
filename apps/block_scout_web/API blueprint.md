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


# Group BlockScoutWeb.Account.Api.V1.AuthController
## BlockScoutWeb.Account.Api.V1.AuthController [/auth/api/logout]
### BlockScoutWeb.Account.Api.V1.AuthController info [GET /auth/api/logout]





+ Logout
**GET**&nbsp;&nbsp;`/auth/api/logout`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNmY5MjFmOGQtNjBiNC00ODE5LTk4MGEtNzFmZjcwYTAyMGNkIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.yX_VbSJf6VKnszqXQXxm7JdkHlxxzmlQYUAF-1HWwoS9tVoWxiEcuo9DDOfVP6xmOSXp_pfabbX10y9XX7rQLw

+ Response 200

    + Body
    
            OK


# Group BlockScoutWeb.Account.Api.V1.UserController
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/info]
### BlockScoutWeb.Account.Api.V1.UserController info [GET /api/account/v1/user/info]


 


+ Request Get info about user
**GET**&nbsp;&nbsp;`/api/account/v1/user/info`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNmY5MjFmOGQtNjBiNC00ODE5LTk4MGEtNzFmZjcwYTAyMGNkIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.yX_VbSJf6VKnszqXQXxm7JdkHlxxzmlQYUAF-1HWwoS9tVoWxiEcuo9DDOfVP6xmOSXp_pfabbX10y9XX7rQLw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnPvkXpQ_AFwAABPB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "nickname": "test_user5",
              "name": "User Test5",
              "email": "test_user-5@blockscout.com",
              "avatar": "https://example.com/avatar/test_user5"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_tag_address [POST /api/account/v1/user/tags/address]


 


+ Request Add private address tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/address`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiN2ZkYjczZWEtYjRhOC00NjQ1LWJiZTMtZDU2OWQyYTM3ODY2IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.hWPDoWz6sjih4_W6d0_dGJzUBDaX8391rX2DhQ_PNo8JhsQ2NlQzGSk8fZ_09GNhGHvoKuZXnyJSHoIu-yt7XQ
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
            x-request-id: FwuQnQulkfs31PUAAB7B
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "MyName",
              "id": 186,
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiN2ZkYjczZWEtYjRhOC00NjQ1LWJiZTMtZDU2OWQyYTM3ODY2IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.hWPDoWz6sjih4_W6d0_dGJzUBDaX8391rX2DhQ_PNo8JhsQ2NlQzGSk8fZ_09GNhGHvoKuZXnyJSHoIu-yt7XQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQvZW8s31PUAAB7h
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
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
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/address/187]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_address [PUT /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `187`
            id: 187


+ Request Edit private address tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/address/187`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMzMwMzNmZTgtZTcwOS00YmU3LWI5Y2MtMzRhOTdjMGM0NzIyIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDI0IiwidHlwIjoiYWNjZXNzIn0.9X0Kzbgoz9dO4NF390Umo4m_iqJbzDbssIl2Rm9WzEL3Q2bkAqtM1Pt_M3-uRTlATOCrlyNCN0LV1UYMPmEQAQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "name3",
              "address_hash": "0x0000000000000000000000000000000000000087"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnRItprfUTWIAACPB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "name3",
              "id": 187,
              "address_hash": "0x0000000000000000000000000000000000000087"
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_address [GET /api/account/v1/user/tags/address]


 


+ Request Get private addresses tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/address`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMDY2MzY5MmEtOGIyMC00NGYwLWExNzItYWJlYmM2OWU5YjQ3IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.48A1cvh2LlJSNm5R-gpJOE5DzikztneJ0BA04Q6vpyjinzWYuI43-L9dQ0zju_OFx_GSQZ2jiVbvMS1qRqW2WA

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQXweZ7Vod4AABrB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "name2",
                "id": 185,
                "address_hash": "0x000000000000000000000000000000000000005f"
              },
              {
                "name": "name1",
                "id": 184,
                "address_hash": "0x000000000000000000000000000000000000005e"
              },
              {
                "name": "name0",
                "id": 183,
                "address_hash": "0x000000000000000000000000000000000000005d"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_address [DELETE /api/account/v1/user/tags/address/{id}]


 

+ Parameters
    + id: `180`
            id: 180


+ Request Delete private address tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/address/180`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMGRmZDM5OWItYzI2My00Mjg2LWFjYzEtN2JhYzdlNzk3ODcwIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.S6enBZxXhYvL5JrJolfuYYDHn_oW36UpHUdyKVi6FHpH5wUZGTeOQ4Gj_9HaNcvm-wC7HNqU5OLTT6epq8rjuw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnPYnRIrQD4QAAAHE
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_tag_transaction [POST /api/account/v1/user/tags/transaction]


 


+ Request Create private transaction tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZWY0ZjZkZDItMmRkMC00ZjliLWFjZDYtYzkwODk4Yjc0Y2FlIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.z81pOVwr8GyKW_uw51OfwKm4m5Tt3URf8Aoymnb_wy6OfatVTUrdYQ75TwyHsBbnt6-isJYI6ZxeAE-OnKydfA
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000006",
              "name": "MyName"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQl3iGVb82YAAB1B
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000006",
              "name": "MyName",
              "id": 209
            }


+ Request Error on try to create private transaction tag for tx does not exist
**POST**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZWY0ZjZkZDItMmRkMC00ZjliLWFjZDYtYzkwODk4Yjc0Y2FlIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.z81pOVwr8GyKW_uw51OfwKm4m5Tt3URf8Aoymnb_wy6OfatVTUrdYQ75TwyHsBbnt6-isJYI6ZxeAE-OnKydfA
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000005",
              "name": "MyName"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQlK1bBb82YAAB0h
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "tx_hash": [
                  "Transaction does not exist"
                ]
              }
            }

# Group BlockScoutWeb.Account.Api.V1.TagsController
## BlockScoutWeb.Account.Api.V1.TagsController [/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000006]
### BlockScoutWeb.Account.Api.V1.TagsController tags_transaction [GET /api/account/v1/tags/transaction/{transaction_hash}]


 

+ Parameters
    + transaction_hash: `0x0000000000000000000000000000000000000000000000000000000000000006`
            transaction_hash: 0x0000000000000000000000000000000000000000000000000000000000000006


+ Request Get tags for transaction
**GET**&nbsp;&nbsp;`/api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000006`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZWY0ZjZkZDItMmRkMC00ZjliLWFjZDYtYzkwODk4Yjc0Y2FlIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.z81pOVwr8GyKW_uw51OfwKm4m5Tt3URf8Aoymnb_wy6OfatVTUrdYQ75TwyHsBbnt6-isJYI6ZxeAE-OnKydfA

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQmM88tb82YAAB1h
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
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
## BlockScoutWeb.Account.Api.V1.UserController [/api/account/v1/user/tags/transaction/204]
### BlockScoutWeb.Account.Api.V1.UserController update_tag_transaction [PUT /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `204`
            id: 204


+ Request Edit private transaction tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/204`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODRkMGU4ZGEtY2JjMi00NjVmLWE2MzgtM2Q3ZjYzY2FjZTdiIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.h6ACZ8fDDQp-XGwcG7mw3-B-kNrM0gdcAVFFTFJPH8p7Yh8c0kN_pSNBfZog1efajV6jZhJlf-XpSaekXDi3KQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "name1"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQNlh9q_YHIAABiB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
              "name": "name1",
              "id": 204
            }
### BlockScoutWeb.Account.Api.V1.UserController tags_transaction [GET /api/account/v1/user/tags/transaction]


 


+ Request Get private transactions tags
**GET**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMTAwZGRiNjUtYzlkYi00NjA5LWIwZTktNzc3OGQ3Y2FjNDU2IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIyIiwidHlwIjoiYWNjZXNzIn0.CykUrkOmwHt_1jl3eu54NXtMzx-v0sbPCPTBilbQf82mTjhXLvNT9Qr8AV9mFm9Yseb8LNVlAfBMhyNs4zbywQ

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnRER4BGMdJQAAAni
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
                "name": "name2",
                "id": 212
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000008",
                "name": "name1",
                "id": 211
              },
              {
                "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000007",
                "name": "name0",
                "id": 210
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_tag_transaction [DELETE /api/account/v1/user/tags/transaction/{id}]


 

+ Parameters
    + id: `205`
            id: 205


+ Request Delete private transaction tag
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/tags/transaction/205`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODNmODk3ZjktMGYwOS00YmE4LTk2NjItYTkwNTgyMjg4YjU4IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEzIiwidHlwIjoiYWNjZXNzIn0.F0g8CraaDyRHqI3wEZRMPMpg-mvyMBT2kExHmdG0Kh0iM7qs0vuHghXKBGZbnRaF_g6ebHj3sqkXNIZqgaHgRw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQf2NAcAeg4AAAZC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Add address to watch list
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNjY2MWJiZDMtZjE5Yy00NGI0LTk1MmYtN2M3N2NmYmU1YjE3IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.W1hndEZ1_BeNMjTRi_NFnsRDrkbZ6odl2kHotJKownHzFqy_aStjwwnvMUDf0eSDbaH41EWVejYkU-e0t3Jb7A
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
                  "incoming": false
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test18",
              "address_hash": "0x0000000000000000000000000000000000000053"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnP-UqzU3wm8AABXB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-721": {
                  "outcoming": false,
                  "incoming": false
                },
                "ERC-20": {
                  "outcoming": false,
                  "incoming": false
                }
              },
              "notification_methods": {
                "email": false
              },
              "name": "test18",
              "id": 210,
              "exchange_rate": null,
              "address_hash": "0x0000000000000000000000000000000000000053",
              "address_balance": null
            }
### BlockScoutWeb.Account.Api.V1.UserController watchlist [GET /api/account/v1/user/watchlist]


 


+ Request Get addresses from watchlists
**GET**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNjY2MWJiZDMtZjE5Yy00NGI0LTk1MmYtN2M3N2NmYmU1YjE3IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.W1hndEZ1_BeNMjTRi_NFnsRDrkbZ6odl2kHotJKownHzFqy_aStjwwnvMUDf0eSDbaH41EWVejYkU-e0t3Jb7A

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQCLxGQ3wm8AABZB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "notification_settings": {
                  "native": {
                    "outcoming": false,
                    "incoming": true
                  },
                  "ERC-721": {
                    "outcoming": false,
                    "incoming": false
                  },
                  "ERC-20": {
                    "outcoming": false,
                    "incoming": false
                  }
                },
                "notification_methods": {
                  "email": false
                },
                "name": "test19",
                "id": 211,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000054",
                "address_balance": null
              },
              {
                "notification_settings": {
                  "native": {
                    "outcoming": false,
                    "incoming": false
                  },
                  "ERC-721": {
                    "outcoming": false,
                    "incoming": false
                  },
                  "ERC-20": {
                    "outcoming": false,
                    "incoming": false
                  }
                },
                "notification_methods": {
                  "email": false
                },
                "name": "test18",
                "id": 210,
                "exchange_rate": null,
                "address_hash": "0x0000000000000000000000000000000000000053",
                "address_balance": null
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_watchlist [DELETE /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `214`
            id: 214


+ Request Delete address from watchlist by id
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/watchlist/214`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOGNiMDRmYjgtMjA1Mi00NjNkLTk4NTYtZWFlNjc5MzBlZjkwIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE5IiwidHlwIjoiYWNjZXNzIn0.Z7mQYkFDdcMSc851qemRQR3Q-IBqA-fIWjmRMZtkvWdskeW1_bbjfOI8DHHaM59wRyzqdbUpihdLaOjF7hxpxw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQ6IcAyZMSkAAAkC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `212`
            id: 212


+ Request Edit watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/212`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTBkNmQ5ZTItNGE2MC00ZDczLWIxZTgtYzRlZDYxYzMwZTk5IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDExIiwidHlwIjoiYWNjZXNzIn0.YRkIi1DrDYXsUBJaAda80uK9zZ5c5q_bMovYS_sVzfZsTWNtVgODi4dHsnwTeMGJb97RU8L12SuiiaEUGB9BNA
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
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
              "name": "test23",
              "address_hash": "0x000000000000000000000000000000000000005c"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQQmuI8HFF0AABlh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": false,
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
              "name": "test23",
              "id": 212,
              "exchange_rate": null,
              "address_hash": "0x000000000000000000000000000000000000005c",
              "address_balance": null
            }
### BlockScoutWeb.Account.Api.V1.UserController create_watchlist [POST /api/account/v1/user/watchlist]


 


+ Request Example of error on creating watchlist address
**POST**&nbsp;&nbsp;`/api/account/v1/user/watchlist`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOTVhOTk1N2ItNjAyMS00MDVhLTk2NTAtYTc5YWIyY2ZkNTllIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.7Oj-gf_a43Lv_7Lw5NWpbsO-pSyIzQXEsuLTnHGyz9OMsaZgmRulXrTezMGjeX1FQ-jdFTFIcNx1_B2hRt1tJQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
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
              "name": "test16",
              "address_hash": "0x0000000000000000000000000000000000000014"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnPsF_80NBRoAABLB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "watchlist_id": [
                  "Address already added to the watch list"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController update_watchlist [PUT /api/account/v1/user/watchlist/{id}]


 

+ Parameters
    + id: `209`
            id: 209


+ Request Example of error on editing watchlist address
**PUT**&nbsp;&nbsp;`/api/account/v1/user/watchlist/209`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOTVhOTk1N2ItNjAyMS00MDVhLTk2NTAtYTc5YWIyY2ZkNTllIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.7Oj-gf_a43Lv_7Lw5NWpbsO-pSyIzQXEsuLTnHGyz9OMsaZgmRulXrTezMGjeX1FQ-jdFTFIcNx1_B2hRt1tJQ
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "notification_settings": {
                "native": {
                  "outcoming": true,
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
              "name": "test16",
              "address_hash": "0x0000000000000000000000000000000000000014"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnPtn2b0NBRoAABMB
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "errors": {
                "watchlist_id": [
                  "Address already added to the watch list"
                ]
              }
            }
### BlockScoutWeb.Account.Api.V1.UserController create_api_key [POST /api/account/v1/user/api_keys]


 


+ Request Add api key
**POST**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWYyYzYyY2QtMmYwNC00OTU3LTljZDAtMWM5OWNkYzhmYjA2IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.6Mgi8a_whFYSD51Z-nkRQOehblhx7HbyPy6n35wxjVANsA7ZL3aiKDdF7p2sNzYkw1dPmAx8LzrZDehVdu_v1g
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQIzqZt_3TEAAAXi
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test",
              "api_key": "fef20f61-10b0-4a0c-8e95-4866a4889b6c"
            }


+ Request Example of error on creating api key
**POST**&nbsp;&nbsp;`/api/account/v1/user/api_keys`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNDBiODFkZWQtZjY5Yi00MjAxLWI3NmEtYzM4YWFiYzkzYzhmIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.iL8cSQTiKO9VN4jpUIunL0HYIe8W1OjlpH0kJXWPjq1xzLs_9_r6La3Uup_ALfEhq7BEt2s7wr1jaVPko99W7g
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test"
            }

+ Response 422

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQzjbeMxzQ0AAB_B
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNDBiODFkZWQtZjY5Yi00MjAxLWI3NmEtYzM4YWFiYzkzYzhmIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.iL8cSQTiKO9VN4jpUIunL0HYIe8W1OjlpH0kJXWPjq1xzLs_9_r6La3Uup_ALfEhq7BEt2s7wr1jaVPko99W7g

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQ0avJQxzQ0AAB_h
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "test",
                "api_key": "93614ffc-1676-4d57-9a62-7d0b125e489a"
              },
              {
                "name": "test",
                "api_key": "b45de683-41eb-462d-b284-02e6ad3bd5e9"
              },
              {
                "name": "test",
                "api_key": "6e696004-25c1-4950-bb18-4c19ae0c6cc7"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController update_api_key [PUT /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `cb4cf42c-c366-4c89-99e4-13000f6f3c67`
            api_key: cb4cf42c-c366-4c89-99e4-13000f6f3c67


+ Request Edit api key
**PUT**&nbsp;&nbsp;`/api/account/v1/user/api_keys/cb4cf42c-c366-4c89-99e4-13000f6f3c67`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWU1NjhhY2ItZGVhYy00YWZhLTkwODUtOGU4OGMxZDFiODdkIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIiLCJ0eXAiOiJhY2Nlc3MifQ.cfYSCi18vPBf4rXf4VI9RbtFaYjZVWhiNKxnNB26_SBl-1uEdtGwYXcvC9FDkGBNk_M2XDehKxFF8EK5egy9hw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test_1"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnPdqSzQmvRQAAAPD
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test_1",
              "api_key": "cb4cf42c-c366-4c89-99e4-13000f6f3c67"
            }
### BlockScoutWeb.Account.Api.V1.UserController delete_api_key [DELETE /api/account/v1/user/api_keys/{api_key}]


 

+ Parameters
    + api_key: `0b952302-aab3-4347-9f2d-2de817fef0d3`
            api_key: 0b952302-aab3-4347-9f2d-2de817fef0d3


+ Request Delete api key
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/api_keys/0b952302-aab3-4347-9f2d-2de817fef0d3`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjI4MDFkYmMtMjZiNi00MTk4LWJkNGEtZWNkMzgyZjZiNDcxIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.sDgN3J5doqMhMePUiIKldbvwPmn9fk4Xt00-t-qYI05Oc06wYctim2r5Gbdzbb4AhAW3iPPnHo_0--fhiV8aUw

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnPEXjB3HPBMAABCh
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_custom_abi [POST /api/account/v1/user/custom_abis]


 


+ Request Add custom abi
**POST**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNWRmM2Y3MmItODM1NS00MjIyLWFmYjgtNTE0MWUxMTM0YmY4IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.t_1KQfANUi8bymIC3rl_GKwpF8pmHFWaV6AZBJrXMartT_hge4aAVE_MHNq133hDq_r24AN2U9bWJmNTj0u01A
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test24",
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
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQo0o9tYelIAAB2B
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test24",
              "id": 449,
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
            }


+ Request Example of error on creating custom abi
**POST**&nbsp;&nbsp;`/api/account/v1/user/custom_abis`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMmNkYjIzZWQtNjg5ZS00M2ZiLWJhY2UtMThkNmI1ZjA2MmJhIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDMiLCJ0eXAiOiJhY2Nlc3MifQ.JZLbq5J8ZoqANBHDXX3hkZUOS8fdRZrOUdIq1uULZBe4Mb2gnVPY2ug0O4zLKLxCvIj4t6DXqUfAq9Afsm5_9Q
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test15",
              "contract_address_hash": "0x0000000000000000000000000000000000000013",
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
            x-request-id: FwuQnPoF3xt_aCMAAAaj
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
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
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMmNkYjIzZWQtNjg5ZS00M2ZiLWJhY2UtMThkNmI1ZjA2MmJhIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDMiLCJ0eXAiOiJhY2Nlc3MifQ.JZLbq5J8ZoqANBHDXX3hkZUOS8fdRZrOUdIq1uULZBe4Mb2gnVPY2ug0O4zLKLxCvIj4t6DXqUfAq9Afsm5_9Q

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnPocnyl_aCMAAAbD
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "name": "test14",
                "id": 447,
                "contract_address_hash": "0x0000000000000000000000000000000000000012",
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
                "id": 446,
                "contract_address_hash": "0x0000000000000000000000000000000000000011",
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
                "id": 445,
                "contract_address_hash": "0x0000000000000000000000000000000000000010",
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
                "id": 444,
                "contract_address_hash": "0x000000000000000000000000000000000000000f",
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
                "name": "test10",
                "id": 443,
                "contract_address_hash": "0x000000000000000000000000000000000000000e",
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
                "name": "test9",
                "id": 442,
                "contract_address_hash": "0x000000000000000000000000000000000000000d",
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
                "name": "test8",
                "id": 441,
                "contract_address_hash": "0x000000000000000000000000000000000000000c",
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
                "name": "test7",
                "id": 440,
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
              },
              {
                "name": "test6",
                "id": 439,
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
              },
              {
                "name": "test5",
                "id": 438,
                "contract_address_hash": "0x0000000000000000000000000000000000000009",
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
                "name": "test4",
                "id": 437,
                "contract_address_hash": "0x0000000000000000000000000000000000000008",
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
                "name": "test3",
                "id": 436,
                "contract_address_hash": "0x0000000000000000000000000000000000000007",
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
                "name": "test2",
                "id": 435,
                "contract_address_hash": "0x0000000000000000000000000000000000000006",
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
                "name": "test1",
                "id": 434,
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
              },
              {
                "name": "test0",
                "id": 433,
                "contract_address_hash": "0x0000000000000000000000000000000000000004",
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
    + id: `448`
            id: 448


+ Request Edit custom abi
**PUT**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/448`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNjg4MWVmYjQtOTZlNy00MTU2LTg2YWUtNmVlNDQ2MWZhNzAzIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.zKX_W91W5X7Vvf-YRnk26wCgu8aFTOBkpYcsH5XrQ-5XBMFwH68dWcRtnJD09zlB-FnU6ycG4C9vlFk02KiJrg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "name": "test21",
              "contract_address_hash": "0x0000000000000000000000000000000000000056",
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
            x-request-id: FwuQnQGu3MsFRCAAAAVC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "name": "test21",
              "id": 448,
              "contract_address_hash": "0x0000000000000000000000000000000000000056",
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
    + id: `450`
            id: 450


+ Request Delete custom abi
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/custom_abis/450`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiN2JmOWVlY2EtZDkzMy00YmFkLWIzMDEtYmFkOTBiYzdiNjY2IiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE2IiwidHlwIjoiYWNjZXNzIn0.7t1rm0x4t5HCE1IhRENVWG_Iq1AUuGoHkezenu4jgiDB96rdQbC9TRASZnLDjjPPuH468IRhsCil7iy8pYxe8A

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQs0IM3_0WMAAAfC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController create_public_tags_request [POST /api/account/v1/user/public_tags]


 


+ Request Submit request to add a public tag
**POST**&nbsp;&nbsp;`/api/account/v1/user/public_tags`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTcyOTA2ZWEtOGI3OS00Zjk3LWIzZmUtMmU3NDk4MDkxYjAzIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIxIiwidHlwIjoiYWNjZXNzIn0.Hq_Fbau0LFELf4Oer6WQXj05jJWRSTedBkAwz3x2HNlFxDzsNtgmmpvWkA9qvr8usmRxye-_jz3tZgD1VElhqg
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "website": "website11",
              "tags": "Tag17;Tag18",
              "is_owner": true,
              "full_name": "full name11",
              "email": "test_user-33@blockscout.com",
              "company": "company11",
              "addresses": [
                "0x0000000000000000000000000000000000000070",
                "0x0000000000000000000000000000000000000071"
              ],
              "additional_comment": "additional_comment11"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnQ9l-uQIRYYAAAmi
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "website": "website11",
              "tags": "Tag17;Tag18",
              "is_owner": true,
              "id": 180,
              "full_name": "full name11",
              "email": "test_user-33@blockscout.com",
              "company": "company11",
              "addresses": [
                "0x0000000000000000000000000000000000000070",
                "0x0000000000000000000000000000000000000071"
              ],
              "additional_comment": "additional_comment11"
            }
### BlockScoutWeb.Account.Api.V1.UserController public_tags_requests [GET /api/account/v1/user/public_tags]


 


+ Request Get list of requests to add a public tag
**GET**&nbsp;&nbsp;`/api/account/v1/user/public_tags`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMWZkMTljNWItZjQzNS00MGI0LTllOWQtMTc5OTllNDhmOTdlIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.wj5e8pYhIOE_XWoQolj-ghI1R3pzEyKTNudIJDN3zcQFa33wO_slJpJxsZaZq_NChLLslMoBmnCKJthZfhYBIA

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnP3ZDj9rrjAAAAjj
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            [
              {
                "website": "website9",
                "tags": "Tag14;Tag15",
                "is_owner": true,
                "id": 178,
                "full_name": "full name9",
                "email": "test_user-16@blockscout.com",
                "company": "company9",
                "addresses": [
                  "0x0000000000000000000000000000000000000052"
                ],
                "additional_comment": "additional_comment9"
              },
              {
                "website": "website8",
                "tags": "Tag13",
                "is_owner": false,
                "id": 177,
                "full_name": "full name8",
                "email": "test_user-15@blockscout.com",
                "company": "company8",
                "addresses": [
                  "0x0000000000000000000000000000000000000048",
                  "0x0000000000000000000000000000000000000049",
                  "0x000000000000000000000000000000000000004a",
                  "0x000000000000000000000000000000000000004b",
                  "0x000000000000000000000000000000000000004c",
                  "0x000000000000000000000000000000000000004d",
                  "0x000000000000000000000000000000000000004e",
                  "0x000000000000000000000000000000000000004f",
                  "0x0000000000000000000000000000000000000050",
                  "0x0000000000000000000000000000000000000051"
                ],
                "additional_comment": "additional_comment8"
              },
              {
                "website": "website7",
                "tags": "Tag11;Tag12",
                "is_owner": true,
                "id": 176,
                "full_name": "full name7",
                "email": "test_user-14@blockscout.com",
                "company": "company7",
                "addresses": [
                  "0x000000000000000000000000000000000000003e",
                  "0x000000000000000000000000000000000000003f",
                  "0x0000000000000000000000000000000000000040",
                  "0x0000000000000000000000000000000000000041",
                  "0x0000000000000000000000000000000000000042",
                  "0x0000000000000000000000000000000000000043",
                  "0x0000000000000000000000000000000000000044",
                  "0x0000000000000000000000000000000000000045",
                  "0x0000000000000000000000000000000000000046",
                  "0x0000000000000000000000000000000000000047"
                ],
                "additional_comment": "additional_comment7"
              },
              {
                "website": "website6",
                "tags": "Tag9;Tag10",
                "is_owner": false,
                "id": 175,
                "full_name": "full name6",
                "email": "test_user-13@blockscout.com",
                "company": "company6",
                "addresses": [
                  "0x000000000000000000000000000000000000003a",
                  "0x000000000000000000000000000000000000003b",
                  "0x000000000000000000000000000000000000003c",
                  "0x000000000000000000000000000000000000003d"
                ],
                "additional_comment": "additional_comment6"
              },
              {
                "website": "website5",
                "tags": "Tag8",
                "is_owner": true,
                "id": 174,
                "full_name": "full name5",
                "email": "test_user-12@blockscout.com",
                "company": "company5",
                "addresses": [
                  "0x0000000000000000000000000000000000000033",
                  "0x0000000000000000000000000000000000000034",
                  "0x0000000000000000000000000000000000000035",
                  "0x0000000000000000000000000000000000000036",
                  "0x0000000000000000000000000000000000000037",
                  "0x0000000000000000000000000000000000000038",
                  "0x0000000000000000000000000000000000000039"
                ],
                "additional_comment": "additional_comment5"
              },
              {
                "website": "website4",
                "tags": "Tag6;Tag7",
                "is_owner": true,
                "id": 173,
                "full_name": "full name4",
                "email": "test_user-11@blockscout.com",
                "company": "company4",
                "addresses": [
                  "0x0000000000000000000000000000000000000031",
                  "0x0000000000000000000000000000000000000032"
                ],
                "additional_comment": "additional_comment4"
              },
              {
                "website": "website3",
                "tags": "Tag5",
                "is_owner": false,
                "id": 172,
                "full_name": "full name3",
                "email": "test_user-10@blockscout.com",
                "company": "company3",
                "addresses": [
                  "0x0000000000000000000000000000000000000028",
                  "0x0000000000000000000000000000000000000029",
                  "0x000000000000000000000000000000000000002a",
                  "0x000000000000000000000000000000000000002b",
                  "0x000000000000000000000000000000000000002c",
                  "0x000000000000000000000000000000000000002d",
                  "0x000000000000000000000000000000000000002e",
                  "0x000000000000000000000000000000000000002f",
                  "0x0000000000000000000000000000000000000030"
                ],
                "additional_comment": "additional_comment3"
              },
              {
                "website": "website2",
                "tags": "Tag4",
                "is_owner": false,
                "id": 171,
                "full_name": "full name2",
                "email": "test_user-9@blockscout.com",
                "company": "company2",
                "addresses": [
                  "0x0000000000000000000000000000000000000020",
                  "0x0000000000000000000000000000000000000021",
                  "0x0000000000000000000000000000000000000022",
                  "0x0000000000000000000000000000000000000023",
                  "0x0000000000000000000000000000000000000024",
                  "0x0000000000000000000000000000000000000025",
                  "0x0000000000000000000000000000000000000026",
                  "0x0000000000000000000000000000000000000027"
                ],
                "additional_comment": "additional_comment2"
              },
              {
                "website": "website1",
                "tags": "Tag2;Tag3",
                "is_owner": true,
                "id": 170,
                "full_name": "full name1",
                "email": "test_user-8@blockscout.com",
                "company": "company1",
                "addresses": [
                  "0x0000000000000000000000000000000000000019",
                  "0x000000000000000000000000000000000000001a",
                  "0x000000000000000000000000000000000000001b",
                  "0x000000000000000000000000000000000000001c",
                  "0x000000000000000000000000000000000000001d",
                  "0x000000000000000000000000000000000000001e",
                  "0x000000000000000000000000000000000000001f"
                ],
                "additional_comment": "additional_comment1"
              },
              {
                "website": "website0",
                "tags": "Tag0;Tag1",
                "is_owner": true,
                "id": 169,
                "full_name": "full name0",
                "email": "test_user-7@blockscout.com",
                "company": "company0",
                "addresses": [
                  "0x0000000000000000000000000000000000000016",
                  "0x0000000000000000000000000000000000000017",
                  "0x0000000000000000000000000000000000000018"
                ],
                "additional_comment": "additional_comment0"
              }
            ]
### BlockScoutWeb.Account.Api.V1.UserController delete_public_tags_request [DELETE /api/account/v1/user/public_tags/{id}]


 

+ Parameters
    + id: `178`
            id: 178


+ Request Delete public tags request
**DELETE**&nbsp;&nbsp;`/api/account/v1/user/public_tags/178`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMWZkMTljNWItZjQzNS00MGI0LTllOWQtMTc5OTllNDhmOTdlIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.wj5e8pYhIOE_XWoQolj-ghI1R3pzEyKTNudIJDN3zcQFa33wO_slJpJxsZaZq_NChLLslMoBmnCKJthZfhYBIA
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "remove_reason": "reason"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnP3w4p5rrjAAAAkj
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "message": "OK"
            }
### BlockScoutWeb.Account.Api.V1.UserController update_public_tags_request [PUT /api/account/v1/user/public_tags/{id}]


 

+ Parameters
    + id: `181`
            id: 181


+ Request Edit request to add a public tag
**PUT**&nbsp;&nbsp;`/api/account/v1/user/public_tags/181`

    + Headers
    
            authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkwOTEsImlhdCI6MTY2MDU3OTg5MSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZmRjNDRmOTAtYzViMy00MjJjLTk4MGQtZjE5MWQzMDEzYmUxIiwibmJmIjoxNjYwNTc5ODkwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIzIiwidHlwIjoiYWNjZXNzIn0.TxgamYKfzZqUXdVA4RsbFJ4_ozJfQzz4wVRBIyFLgrMGWi-7tZe5Lh3Oe_2LCKuf4Q4uZ9GQM5bD0V5WWk-YZw
            content-type: multipart/mixed; boundary=plug_conn_test
    + Body
    
            {
              "website": "website13",
              "tags": "Tag20;Tag21",
              "is_owner": false,
              "full_name": "full name13",
              "email": "test_user-37@blockscout.com",
              "company": "company13",
              "addresses": [
                "0x0000000000000000000000000000000000000080",
                "0x0000000000000000000000000000000000000081",
                "0x0000000000000000000000000000000000000082",
                "0x0000000000000000000000000000000000000083",
                "0x0000000000000000000000000000000000000084",
                "0x0000000000000000000000000000000000000085"
              ],
              "additional_comment": "additional_comment13"
            }

+ Response 200

    + Headers
    
            content-type: application/json; charset=utf-8
            cache-control: max-age=0, private, must-revalidate
            x-request-id: FwuQnRGPAcIPFzIAAApC
            access-control-allow-credentials: true
            access-control-allow-origin: *
            access-control-expose-headers: 
    + Body
    
            {
              "website": "website13",
              "tags": "Tag20;Tag21",
              "is_owner": false,
              "id": 181,
              "full_name": "full name13",
              "email": "test_user-37@blockscout.com",
              "company": "company13",
              "addresses": [
                "0x0000000000000000000000000000000000000080",
                "0x0000000000000000000000000000000000000081",
                "0x0000000000000000000000000000000000000082",
                "0x0000000000000000000000000000000000000083",
                "0x0000000000000000000000000000000000000084",
                "0x0000000000000000000000000000000000000085"
              ],
              "additional_comment": "additional_comment13"
            }

