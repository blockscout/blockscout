defmodule Explorer.ThirdPartyIntegrations.UniversalProxyTest do
  use ExUnit.Case

  import Mox

  alias Explorer.ThirdPartyIntegrations.UniversalProxy

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    :persistent_term.erase(:universal_proxy_config)
    System.put_env("UNIVERSAL_PROXY_TEST_PLATFORM_API_KEY", "test_api_key")

    on_exit(fn ->
      System.put_env("UNIVERSAL_PROXY_TEST_PLATFORM_API_KEY", "")
    end)

    :ok
  end

  describe "api_request/1" do
    test "successful API request" do
      config_mock()

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body: Jason.encode!(%{"success" => true})
        }
      )

      proxy_params = %{"platform_id" => "test_platform"}
      {_response_body, status} = UniversalProxy.api_request(proxy_params)

      assert status == 200
    end

    test "invalid platform configuration" do
      config_mock()
      proxy_params = %{"platform_id" => "nonexistent_platform"}
      {error_message, status} = UniversalProxy.api_request(proxy_params)

      assert status == 422

      assert error_message ==
               "Invalid config: Platform 'nonexistent_platform' not found in config or 'platforms' property doesn't exist at all"
    end

    test "missing base_url in platform configuration" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test",
                      "method" => "get",
                      "params" => []
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      proxy_params = %{"platform_id" => "test_platform"}
      {error_message, status} = UniversalProxy.api_request(proxy_params)

      assert status == 422

      assert error_message ==
               "Invalid config: 'base_url' is not defined for platform_id 'test_platform' or 'base' endpoint is not defined or 'base' endpoint path is not defined"
    end

    test "invalid HTTP method" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test",
                      "method" => "invalid_method",
                      "params" => []
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      proxy_params = %{"platform_id" => "test_platform"}
      {error_message, status} = UniversalProxy.api_request(proxy_params)

      assert status == 422
      assert error_message == "Invalid config: Invalid HTTP request method for platform 'test_platform'"
    end

    test "unexpected error during request" do
      config_mock()

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: {:error, :timeout}
      )

      proxy_params = %{"platform_id" => "test_platform"}
      {error_message, status} = UniversalProxy.api_request(proxy_params)

      assert status == 500
      assert error_message == "Unexpected error when calling proxied endpoint"
    end
  end

  describe "parse_proxy_params/2" do
    test "correctly parsing address param in the path" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test/:address",
                      "method" => "get",
                      "params" => [
                        %{
                          "location" => "path",
                          "type" => "address"
                        }
                      ]
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      assert "https://api.test.com/test/0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
               }).url
    end

    test "correctly parsing address param and chain_id in the path" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test/:chain_id/:address",
                      "method" => "get",
                      "params" => [
                        %{
                          "location" => "path",
                          "type" => "address"
                        },
                        %{
                          "location" => "path",
                          "type" => "chain_id"
                        }
                      ]
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      assert "https://api.test.com/test/1/0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
                 "chain_id" => "1"
               }).url
    end

    test "correctly parsing chain_id - dependent param in the path when chain id is NOT present as param" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test/:endpoint_platform_id",
                      "method" => "get",
                      "params" => [
                        %{
                          "location" => "path",
                          "type" => "chain_id_dependent",
                          "name" => "endpoint_platform_id",
                          "mapping" => %{
                            "1" => "first_endpoint_platform_id",
                            "100500" => "another_endpoint_platform_id"
                          }
                        }
                      ]
                    }
                  }
                }
              }
            })
        }
      )

      assert "https://api.test.com/test/another_endpoint_platform_id" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "chain_id" => "100500"
               }).url
    end

    test "correctly parsing chain_id - dependent param in the path when chain id is present as param as well" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test/:endpoint_platform_id/:chain_id",
                      "method" => "get",
                      "params" => [
                        %{
                          "location" => "path",
                          "type" => "chain_id"
                        },
                        %{
                          "location" => "path",
                          "type" => "chain_id_dependent",
                          "name" => "endpoint_platform_id",
                          "mapping" => %{
                            "1" => "first_endpoint_platform_id",
                            "100500" => "another_endpoint_platform_id"
                          }
                        }
                      ]
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      assert "https://api.test.com/test/another_endpoint_platform_id/100500" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "chain_id" => "100500"
               }).url
    end

    test "correctly parsing address param in the query string" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test",
                      "method" => "get",
                      "params" => [
                        %{
                          "location" => "query",
                          "type" => "address"
                        }
                      ]
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      assert "https://api.test.com/test?address=0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
               }).url
    end

    test "correctly parsing multiple params in the query string" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test",
                      "method" => "get",
                      "params" => [
                        %{
                          "location" => "query",
                          "type" => "address"
                        },
                        %{
                          "location" => "query",
                          "name" => "second_param",
                          "value" => "42"
                        }
                      ]
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      assert "https://api.test.com/test?address=0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5&second_param=42" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
               }).url
    end

    test "correctly parsing address param in the request body" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test",
                      "method" => "post",
                      "params" => [
                        %{
                          "location" => "body",
                          "type" => "address"
                        }
                      ]
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      assert "address=0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5&" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
               }).body
    end

    test "correctly parsing address param in the request header" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test",
                      "method" => "post",
                      "params" => [
                        %{
                          "location" => "header",
                          "type" => "address",
                          "name" => "X-Address"
                        }
                      ]
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "Authorization",
                    "prefix" => "Bearer"
                  }
                }
              }
            })
        }
      )

      assert [{"X-Address", "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"}, {"Authorization", "Bearer test_api_key"}] =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
               }).headers
    end

    test "correctly apply api key to the headers" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/test",
                      "method" => "post",
                      "params" => []
                    }
                  },
                  "api_key" => %{
                    "location" => "header",
                    "param_name" => "X_API_KEY"
                  }
                }
              }
            })
        }
      )

      assert [{"X_API_KEY", "test_api_key"}] =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
               }).headers
    end

    test "correctly apply api key to the query string" do
      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: %Tesla.Env{
          status: 200,
          body:
            Jason.encode!(%{
              "platforms" => %{
                "test_platform" => %{
                  "base_url" => "https://api.test.com",
                  "endpoints" => %{
                    "base" => %{
                      "path" => "/",
                      "method" => "get",
                      "params" => []
                    }
                  },
                  "api_key" => %{
                    "location" => "query",
                    "param_name" => "api_key"
                  }
                }
              }
            })
        }
      )

      assert "https://api.test.com/?api_key=test_api_key" =
               UniversalProxy.parse_proxy_params(%{
                 "platform_id" => "test_platform",
                 "address" => "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
               }).url
    end
  end

  defp config_mock do
    Tesla.Test.expect_tesla_call(
      times: 1,
      returns: %Tesla.Env{
        status: 200,
        body:
          Jason.encode!(%{
            "platforms" => %{
              "test_platform" => %{
                "base_url" => "https://api.test.com",
                "endpoints" => %{
                  "base" => %{
                    "path" => "/test",
                    "method" => "get",
                    "params" => []
                  }
                },
                "api_key" => %{
                  "location" => "header",
                  "param_name" => "Authorization",
                  "prefix" => "Bearer"
                }
              }
            }
          })
      }
    )
  end
end
