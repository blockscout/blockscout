defmodule Explorer.Chain.Filecoin.NativeAddressTest do
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :filecoin do
    use ExUnit.Case, async: true
    # TODO: remove when https://github.com/elixir-lang/elixir/issues/13975 comes to elixir release
    alias Explorer.Chain.Hash, warn: false
    alias Explorer.Chain.Filecoin.{NativeAddress, IDAddress}

    doctest NativeAddress
    doctest IDAddress

    @doc """
    The following test cases are taken from the filecoin spec:
    https://spec.filecoin.io/appendix/address/#section-appendix.address.test-vectors

    The key is the address and the value is the hex-encoded binary representation
    of the address in the database.
    """
    # cspell:disable
    @test_cases %{
      "f00" => "0000",
      "f0150" => "009601",
      "f01024" => "008008",
      "f01729" => "00c10d",
      "f018446744073709551615" => "00ffffffffffffffffff01",
      "f17uoq6tp427uzv7fztkbsnn64iwotfrristwpryy" => "01fd1d0f4dfcd7e99afcb99a8326b7dc459d32c628",
      "f1xcbgdhkgkwht3hrrnui3jdopeejsoatkzmoltqy" => "01b882619d46558f3d9e316d11b48dcf211327026a",
      "f1xtwapqc6nh4si2hcwpr3656iotzmlwumogqbuaa" => "01bcec07c05e69f92468e2b3e3bf77c874f2c5da8c",
      "f1wbxhu3ypkuo6eyp6hjx6davuelxaxrvwb2kuwva" => "01b06e7a6f0f551de261fe3a6fe182b422ee0bc6b6",
      "f12fiakbhe2gwd5cnmrenekasyn6v5tnaxaqizq6a" => "01d1500504e4d1ac3e89ac891a4502586fabd9b417",
      "f24vg6ut43yw2h2jqydgbg2xq7x6f4kub3bg6as6i" => "02e54dea4f9bc5b47d261819826d5e1fbf8bc5503b",
      "f25nml2cfbljvn4goqtclhifepvfnicv6g7mfmmvq" => "02eb58bd08a15a6ade19d0989674148fa95a8157c6",
      "f2nuqrg7vuysaue2pistjjnt3fadsdzvyuatqtfei" => "026d21137eb4c4814269e894d296cf6500e43cd714",
      "f24dd4ox4c2vpf5vk5wkadgyyn6qtuvgcpxxon64a" => "02e0c7c75f82d55e5ed55db28033630df4274a984f",
      "f2gfvuyh7v2sx3patm5k23wdzmhyhtmqctasbr23y" => "02316b4c1ff5d4afb7826ceab5bb0f2c3e0f364053",
      "f3vvmn62lofvhjd2ugzca6sof2j2ubwok6cj4xxbfzz4yuxfkgobpihhd2thlanmsh3w2ptld2gqkn2jvlss4a" =>
        "03ad58df696e2d4e91ea86c881e938ba4ea81b395e12797b84b9cf314b9546705e839c7a99d606b247ddb4f9ac7a3414dd",
      "f3wmuu6crofhqmm3v4enos73okk2l366ck6yc4owxwbdtkmpk42ohkqxfitcpa57pjdcftql4tojda2poeruwa" =>
        "03b3294f0a2e29e0c66ebc235d2fedca5697bf784af605c75af608e6a63d5cd38ea85ca8989e0efde9188b382f9372460d",
      "f3s2q2hzhkpiknjgmf4zq3ejab2rh62qbndueslmsdzervrhapxr7dftie4kpnpdiv2n6tvkr743ndhrsw6d3a" =>
        "0396a1a3e4ea7a14d49985e661b22401d44fed402d1d0925b243c923589c0fbc7e32cd04e29ed78d15d37d3aaa3fe6da33",
      "f3q22fijmmlckhl56rn5nkyamkph3mcfu5ed6dheq53c244hfmnq2i7efdma3cj5voxenwiummf2ajlsbxc65a" =>
        "0386b454258c589475f7d16f5aac018a79f6c1169d20fc33921dd8b5ce1cac6c348f90a3603624f6aeb91b64518c2e8095",
      "f3u5zgwa4ael3vuocgc5mfgygo4yuqocrntuuhcklf4xzg5tcaqwbyfabxetwtj4tsam3pbhnwghyhijr5mixa" =>
        "03a7726b038022f75a384617585360cee629070a2d9d28712965e5f26ecc40858382803724ed34f2720336f09db631f074"
    }

    # cspell:enable

    describe "cast/1" do
      test "parses f0, f1, f2, f3 addresses from spec test vectors" do
        for {address, hex_string} <- @test_cases do
          {protocol_indicator_hex, payload} = String.split_at(hex_string, 2)
          protocol_indicator = String.to_integer(protocol_indicator_hex, 16)
          payload = Base.decode16!(payload, case: :lower)

          assert {:ok,
                  %NativeAddress{
                    protocol_indicator: ^protocol_indicator,
                    actor_id: nil,
                    payload: ^payload
                  }} = NativeAddress.cast(address)
        end
      end

      test "parses f4 addresses" do
        address = "f410fabpafjfjgqkc3douo3yzfug5tq4bwfvuhsewxji"
        {:ok, %Hash{bytes: eth_address_bytes}} = Hash.Address.cast("0x005E02A4A934142D8DD476F192D0DD9C381B16B4")

        assert {:ok,
                %NativeAddress{
                  protocol_indicator: 4,
                  actor_id: 10,
                  payload: ^eth_address_bytes
                }} = NativeAddress.cast(address)
      end

      test "parses 0x addresses" do
        {:ok, %Hash{bytes: eth_address_bytes} = eth_address_hash} =
          Hash.Address.cast("0x005E02A4A934142D8DD476F192D0DD9C381B16B4")

        assert {:ok,
                %NativeAddress{
                  protocol_indicator: 4,
                  actor_id: 10,
                  payload: ^eth_address_bytes
                }} = NativeAddress.cast(eth_address_hash)
      end

      test "parses 0x addresses and f410 addresses to matched representations" do
        native_address_string = "f410fqo6xn6yojh2t4deb2izx7rmatbtgvfe2gaciifi"
        {:ok, eth_address_hash} = Hash.Address.cast("0x83bD76FB0E49F53E0C81d2337FC58098666A949A")

        assert NativeAddress.cast(native_address_string) == NativeAddress.cast(eth_address_hash)
      end
    end

    describe "dump/1" do
      test "encodes f0, f1, f2, f3 addresses to bytes" do
        for {address, hex_string} <- @test_cases do
          bytes = Base.decode16!(hex_string, case: :lower)

          assert {:ok, ^bytes} =
                   address
                   |> NativeAddress.cast()
                   |> elem(1)
                   |> NativeAddress.dump()
        end
      end

      test "converts f4 addresses" do
        address = "f410fabpafjfjgqkc3douo3yzfug5tq4bwfvuhsewxji"
        {:ok, evm_address} = Hash.Address.cast("0x005E02A4A934142D8DD476F192D0DD9C381B16B4")
        bytes = <<4, 10, evm_address.bytes::binary>>

        assert {:ok, ^bytes} =
                 address
                 |> NativeAddress.cast()
                 |> elem(1)
                 |> NativeAddress.dump()
      end
    end

    describe "load/1" do
      test "decodes f0, f1, f2, f3 addresses from bytes" do
        for {address, hex_string} <- Map.values(@test_cases) do
          {protocol_indicator_hex, payload_hex} = String.split_at(hex_string, 2)
          protocol_indicator = String.to_integer(protocol_indicator_hex, 16)
          payload = Base.decode16!(payload_hex, case: :lower)

          assert {:ok,
                  %NativeAddress{
                    protocol_indicator: ^protocol_indicator,
                    actor_id: nil,
                    payload: ^payload
                  }} =
                   address
                   |> NativeAddress.cast()
                   |> elem(1)
                   |> NativeAddress.dump()
                   |> elem(1)
                   |> NativeAddress.load()
        end
      end

      test "decodes f4 addresses" do
        address = "f410fabpafjfjgqkc3douo3yzfug5tq4bwfvuhsewxji"
        {:ok, %Hash{bytes: payload}} = Hash.Address.cast("0x005E02A4A934142D8DD476F192D0DD9C381B16B4")

        assert {:ok,
                %NativeAddress{
                  protocol_indicator: 4,
                  actor_id: 10,
                  payload: ^payload
                }} =
                 address
                 |> NativeAddress.cast()
                 |> elem(1)
                 |> NativeAddress.dump()
                 |> elem(1)
                 |> NativeAddress.load()
      end
    end

    describe "to_string/1" do
      test "converts f0, f1, f2, f3 addresses to string" do
        for {address, _} <- @test_cases do
          assert ^address =
                   address
                   |> NativeAddress.cast()
                   |> elem(1)
                   |> NativeAddress.dump()
                   |> elem(1)
                   |> NativeAddress.load()
                   |> elem(1)
                   |> NativeAddress.to_string()
        end
      end

      test "converts f4 addresses to string" do
        address = "f410fabpafjfjgqkc3douo3yzfug5tq4bwfvuhsewxji"

        assert ^address =
                 address
                 |> NativeAddress.cast()
                 |> elem(1)
                 |> NativeAddress.dump()
                 |> elem(1)
                 |> NativeAddress.load()
                 |> elem(1)
                 |> NativeAddress.to_string()
      end

      test "converts ethereum addresses to string" do
        {:ok, eth_address_hash} = Hash.Address.cast("0x83bD76FB0E49F53E0C81d2337FC58098666A949A")
        address = "f410fqo6xn6yojh2t4deb2izx7rmatbtgvfe2gaciifi"

        assert ^address =
                 eth_address_hash
                 |> NativeAddress.cast()
                 |> elem(1)
                 |> NativeAddress.dump()
                 |> elem(1)
                 |> NativeAddress.load()
                 |> elem(1)
                 |> to_string()
      end
    end
  end
end
