# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.UrlValidatorTest do
  use ExUnit.Case, async: false

  alias Utils.UrlValidator

  setup do
    previous = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)

    Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper,
      host_filtering_enabled?: true,
      cidr_blacklist: [],
      allowed_uri_protocols: ["http", "https"]
    )

    :persistent_term.erase(:parsed_cidr_list)

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper, previous)
      :persistent_term.erase(:parsed_cidr_list)
    end)

    :ok
  end

  describe "validate_uri/1 with IPv4 literals" do
    test "blocks reserved IPv4 ranges" do
      for host <- [
            "127.0.0.1",
            "169.254.169.254",
            "10.0.0.1",
            "172.16.0.1",
            "192.168.1.1",
            "0.0.0.0",
            "255.255.255.255"
          ] do
        assert UrlValidator.validate_uri("http://#{host}/metadata.json") == {:error, :blacklist},
               "expected #{host} to be blacklisted"
      end
    end

    test "allows public IPv4 literals" do
      for host <- ["8.8.8.8", "1.1.1.1"] do
        assert UrlValidator.validate_uri("http://#{host}/metadata.json") == :ok,
               "expected #{host} to be allowed"
      end
    end
  end

  describe "validate_uri/1 with IPv6 literals (regression for IPv4-only reserved ranges)" do
    test "blocks IPv6 loopback, ULA and link-local" do
      for host <- ["[::1]", "[fd00::1]", "[fe80::1]"] do
        assert UrlValidator.validate_uri("http://#{host}/metadata.json") == {:error, :blacklist},
               "expected #{host} to be blacklisted"
      end
    end

    test "blocks IPv4-mapped IPv6 pointing at internal addresses" do
      for host <- ["[::ffff:127.0.0.1]", "[::ffff:169.254.169.254]"] do
        assert UrlValidator.validate_uri("http://#{host}/metadata.json") == {:error, :blacklist},
               "expected #{host} to be blacklisted"
      end
    end

    test "allows public IPv6 literals" do
      assert UrlValidator.validate_uri("http://[2606:4700:4700::1111]/metadata.json") == :ok
    end
  end

  describe "validate_uri/1 general validation" do
    test "rejects disallowed protocols" do
      assert UrlValidator.validate_uri("ftp://8.8.8.8/metadata.json") == {:error, :disallowed_protocol}
    end

    test "rejects empty host" do
      assert UrlValidator.validate_uri("/just/a/path") == {:error, :empty_host}
    end

    test "rejects non-printable input" do
      assert UrlValidator.validate_uri("http://8.8.8.8/" <> <<0xFF>>) == {:error, :not_printable}
    end
  end

  describe "validate_uri/1 with operator cidr_blacklist" do
    test "blocks a host added to the configured blacklist" do
      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper,
        host_filtering_enabled?: true,
        cidr_blacklist: ["8.8.8.8/32"],
        allowed_uri_protocols: ["http", "https"]
      )

      :persistent_term.erase(:parsed_cidr_list)

      assert UrlValidator.validate_uri("http://8.8.8.8/metadata.json") == {:error, :blacklist}
    end
  end
end
