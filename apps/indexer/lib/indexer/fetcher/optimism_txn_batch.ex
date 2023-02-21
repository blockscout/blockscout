defmodule Indexer.Fetcher.OptimismTxnBatch do
  @moduledoc """
  Fills op_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [fetch_blocks_by_range: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.OptimismTxnBatch
  alias Indexer.BoundQueue
  alias Indexer.Fetcher.Optimism

  @block_check_interval_range_size 100
  @eth_get_block_range_size 5

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    Logger.metadata(fetcher: :optimism_txn_batch)

    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         optimism_rpc_l1 = Application.get_env(:indexer, :optimism_rpc_l1),
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_rpc_l1)},
         {:batch_inbox_valid, true} <- {:batch_inbox_valid, Optimism.is_address?(env[:batch_inbox])},
         {:batch_submitter_valid, true} <- {:batch_submitter_valid, Optimism.is_address?(env[:batch_submitter])},
         start_block_l1 = Optimism.parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         json_rpc_named_arguments = json_rpc_named_arguments(optimism_rpc_l1),
         {last_l1_block_number, last_l1_tx_hash, last_l1_tx} = get_last_l1_item(json_rpc_named_arguments),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_tx_hash) && is_nil(last_l1_tx)},
         {:ok, last_safe_block} <- Optimism.get_block_number_by_tag("safe", json_rpc_named_arguments),
         first_block = max(last_safe_block - @block_check_interval_range_size, 1),
         {:ok, first_block_timestamp} <- Optimism.get_block_timestamp_by_number(first_block, json_rpc_named_arguments),
         {:ok, last_safe_block_timestamp} <-
           Optimism.get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")

      start_block = max(start_block_l1, last_l1_block_number)

      # https://goerli.etherscan.io/tx/0x573c2d47dedaaf22cf3ea2d6cb4905f038be0d5c49c6c145ee1f00313505228d
      # bytes = Base.decode16!("78daecbc07549449b33f3c819c338844010992254a062549109024202020592549866140104482e4e88320398bc010648802922408a2e41c24a75194eff8dee575f7bb2ba8ecbe7befffdc3e478e4c53cf74575757d5f3ab5f37028d188442c307aeec56f65dd4a858bca6e7f6e1559bc64acc33d2107fb4308b2c66723bbed2abe1fe7ebdef8125d2da694c9189a2f5e229a7915c54c4a0c2108f9cbac43bf15d2dbdfcc94b6a0166ab89b928685de56bc85e171c9cc10c87cec3a1f3fe687eedd141591baf55d4b1070cb6c99c1e2e396e312466d9c12acda7d6ec3d41bf6b26b4657daf4ef150e89f0fb14cb1de571c2516bbfdfb7e8b676053cee42cbb574aba6706d738fbf2f38cb841df6bb8e98c98cd572b9130c0416b964c43abfa944d2bd50b2ea891217584acc6823167fc0a0d5ee61297a201804992f5fc4d8c8f712d600d77f53d95fac9e10d61f43bb7ab5cd83ae32e6eca0f106027080a7c1b0ece20f96d52e0494834bd35bfbc056154d6c25616a9426cccfdd3b1cfd76108309ac8074ad1ef0dea925924fce216e8fbcddb8caa96795d0e7474037eff4b0ea63db296c5d59e0da56d1e6334a0ba9203ce384ad86c35a9ec98e7437eff4bfea696198e551861de2babbcdae78961528a67758e5b15240c609cc818f508f1f280200dd99470d3a7ee2e4c7817e2faed5fb52c51d0d14ecd062ccf418346f5e4bce790dc83f3097e74028b8577184b8477b8ca5a8afc4a184dbf699df037ad43ec28beabf5f929e13f4cc1c686c734d3a2927258714dd04e41dab6878fb5f16766f5c7a6af4d5b15a1f6bd5e53e62f0b51354729546fb25936eebbab6a929d9980170ffbc3673c4393c4866f99b8cb7378037b862bf06f4a97a81cb3aa1d5f6d7de86328275fb787c4fceece64792f0fa9298aa52549bc7de594b867d54a0031204250581d92cae9e5828385cb8c89fcb2ad868d211f29ae35268b21d3f84a7013015d01a1a08b80f06cf7875074e0ac4f485a8816ec19e372ec5df70f4c1d075d9ba989c344e3affdfd7a4780b87dcc73e312ae45375487d8870697084af43fdbca3bd1a17d126d3e4b6dfcd6e9ab4fc84741932b0bf7f2e1e65afef1b130ff9b9c86d1a01744cee3034f62fce97bc644b8b52c05e75a0c60951729fd8d68fe7c763429a053d657c1b71ced8fd64162361c6a0b54aa5b060b64669bb9478872816ee70873f7f3de1ee3dc2299b3516274bdd36f05c8dcb175cc51608324a9af61de0d5eeccc66017955acdbb65fbed19c3c163a95f1cdf4580e4d0f47f4874d0f72ff6ae97dd3ec464e3204666ac5e459d9bc18925f363d9be841f5efbb03280a70f5a0090857fcbe3c9e4df903e0bbf25bc173f7d0b55fd3fffec389218378f9c047d49a6773a5a8ab7cb57ca133e1c798de6b240c08089436957fc197d5e1726179ea5686958e0fcb1bdd77971c14690ed666f4c3ce0317a4b71764d326a6cb26f72f89230d14bf24e6e187e425d4b923c77259c4212fbe691dff50ebe8cbbfe2664f534fbf995cbdf2dd0153a6b6ee33ca313ea7f81937cb49c6856b24b612ac8a2e5aa3dacfec4d78a1aaf118adb4fe956e564063c67169a8869d214effbca9b3327d183f6d08120caca56ac55dcf3d651637573fb33c4007c5bee17a47aa7537f84e674e9db4498b0980cb125f79a9ad91f5ce96979588f244bf1dda9491f39b4ba91d434892f081154704da39100a8d15c861012cf2f1ad7170747caaeb4a282ec95e0285c83c724cc793b1d955534f25fbe10d5f8882be4540df4050d05e3838c31f2ded349c9508ce4ae40fcd288e7e492e25bcf1715cfc931d99c13926cac0c7f7866c6108a8b9dd8a6de0cfacc67f6fe0f163946d724cff31f2c736e831fd26279b1fe8b8f1615dd55291e1d1d6baf88be3c75450bd74027110969cba92da091e709cfeb0fee6fea3be1fed39cb7dc5a384615d92d24719e73dde31e084f3079fb41f090668a1924b44612e7d60d3e95a84c806e6ec5b9195e1b424f40392c757edafde5e0144d764974ac3ac6a1a1db6cf25c27d3ebd975511bfb38e055d36f998c1ccb89a8480c8825010492085d2042e98564df1b0ab726ef5d5c8bb00ef81acfaaa9bc4f1331edeacf226323fec2d8a51e0b54a37c89e0b1c9c0127920bd0b7e2017dfd7113ae89152db1d944e7de8a537497740ebfcd5047175ba7f14b10f4a14f460b0c04438201d54a1a0561ff9e0d924fd648614c89d88518453b3c5e3a8c56f29e620f9e2fcb80c0d38ad6aafb747aabf475e3efd12b24452516f7fcc1704ce18311c9dc4e1bd96f2187f430b3dfd1fca5cc3ee425135af0fc11dac7686775b54797f8192710b96e64598156c891b8c3679b1e21d7d7688ab7774cc8e9fc0f64f609d8b722a43a9705e81aa455d5e80a2ea85362987593cac85fccbe234de6789e09d092c2ab1e2ac541be70ef7419b53fd59ab50f26d2ae7c72e3698783d9c29ef120024b1a84c21207208f164e51e26bcd4eabc2b92ed3a5098c0ab19dd29454d2d478f0bc81f4aa8bff0f1b51290a730581e1024161387c35238ceaaf8b8926ea6ff010167de64af9a790d53e13f7470ad88f8c576fbb18b130c210186825ef2d3240e0d19281cd9e8de7328fc857023df39945b8249d24f138ece18fd2561325a58e562525f872d9f39817ab46143e810c2f2d1519d0060bd066ddf599ad67fa74f433a398364ee6d1d18f1147879d2c60a11df7070c7f6fc4021f1311a1c81346e4e33ca2c8cfc8bfe77c4934cda66bc9ed8ed9ada06c5d2e1685f5f868f16ceba3a2adc4b01770c2f133fcc45eff05f923c77f9cfe28b5a306fff041c54a3f87076ba5e908e871eb4099d6a3cfe225174eb43e507ce99f3106d2c73b2a37a6e0c6ee13aef570d07c99cea0f631ce180c3b2ea0fe016f4a318a14ba677c7b591c3beacbec425708bb9b3cbfc7ba6cb0cdc564aa51bc9b2a4d797133e74f357324f9c3c13e84977baf66349d70ffdd01fdbd0d1a940b23a5a6822fa71670b98d2810d37715092cd7ee9d9fcb7a923c30e077fa2ea1b4aff886cc3da695b9cf5a6ba71e0b46aee5967ff6c05d6060fbe8064074c25ac8b09c22f929bacf6106229ce04d97e37018edd2d9bc5ef0f10c23bb92a5858ffb7e1c9137ba0136911fe885ce0e33dc7dcf87b27fa5582fe4f2b02a4a93472e95539e718892ca698ca164d147f31a778191bed1a8c7f9cf1c64bc970288de059260999ce6c89439c3d9be5a93cf7f37b8682ec1b4dbb2e5ac1538dca6e3e9b9896b78424830e0ae46561ab24606c988b31dc42bdebee170beba9876b75c6af38dd5969eb4e41e70f7de50ef3ee9a86f54b9cfd4a6230a25f0f14a0dbf5e5d3c011d7fce63e3ccec6f2904d6e15b2bcbc2afa41060f230796cd29e23f4c18ae426ab584efa19af6c99214c2590d08d7596973e0790b2e9348db7ae3f3a85c819fd2b5308eff517988f13304c29f718e5758ad131c236da8d9130c0edfabb3c4cd72b86192317481eca940a2607d7586adff653d97b3fe6af54e59f06dca0f750fb128cd82cd83371187d53b096bd2c9a2214b8d7599cd2031d4a51a2456066815098e94031f5bc3a0fe753857b98227483f7c76b1a752700a3a0e0599b0a5c3fc19ee18d1f4e21ca5098dadf9692f5df382fc1af2c25baedcbeb5c664447c5def5b920c73af39f59ca610b42a0887a7e43a03ee2515b32b6d0cdb964ef63b2c1bebf7229ff0c5145c280b29b22ad0dbb6a0a033b0baa23a3eee7cff1319078aac42fc5d0bc9fa97f27c60c5ca074e4337e32dd2a92fb7883b03c86a6d77864553e7dc34ef4406ae0b1e1f56c04a40705e9f487c2a5bf6a1c338d215aa7a7f269940c411e7d4510a98436c17bc590d1eb3004c4bc0de6227acc8c8e73d9c0710a01ff7519474860c0358bdee4cc45bdc45b0c37b6ed40d08e45741018023dc117989c24a7c36a2510fe27fbbf2a38e466d0f99d2e2221a2b5b30ac52631232cde4040d3c3f8190ef9e5d9be677e41fc126dc17326feb9cfdeb9120fb488b502b9783d7d1aef08b6df9ff2592f801f1cf77c37a2d60bd403a194185d4282afce3c6a945098a04d6124e87829aa28b03798bbc8387bedc96ae75c523357b5a374ff03ebaa22373532c907b251b28c5a41a677cfc3a1b640f0b6b28ffc128d57cd18578a118a0c11feb9c8e31da5342adf07de34b329ee06dc7ae789a1bdc34b16cc9e0cc2ebedcfe845b5aa35a15ff7df6b63f7fa3cfcd20d018e82a0c0e1707006c56f8e042a01fe9e23613eeab512edb2c2db869bdf4f843983e2bb3232ed577ec691ec9b79d853e13b26dc0fc8fe32b9ce21c62cbebe728c2359f919ece2a4a517b1d8f28bede3d641191ba452746476de335d9bf9483030cdd7c957d9352635ae3556b72cfc385faa4116ab24d738d86c47a8606918fb0170aa1837ca52a4cf03cfd5e1b632eb46e6d974b20e1ac1a757acef730fb8be7161f8efee1d621ffdcf1494c4900e0655f3df8bc4d2bb440ddeef71d33e7e5fde697b411f05ff9e7cfafc97edd0119f3f640a4a6478e788df0b57a3697ce4348bbbf836d03b3af09855cf448281785756aee4ea3e73d13753a42afc4d09418d52d583cc3569de98f8530ea7d91300a732c3dd6e2549f1d57a2fb8308a33b2bb63d82645c37f4bf7319a88c985bd2c04941784827202d7e05d176ff15ee978166570c16c5a6a0fa53b7aa0b52258e3b285494e691c48f3c391ba1c0519458085202830ffd7977d320e7f4259e97ffd83f09347df37111bebf77c9a1db609c1bb798d67b4d3afd71756d944a5bb297fb2d07144236e74171eff9e3884eed4785b55a9f4cfc50ea78edde636d24b9a104fe38b8e752fd39a9fec9d45c2001135d7ec50fbf27333381169349acd043c9867946b5e5a64a7b0b30b1afb28fb002e8ba0f2edd1f691d45ad9909e27b02644869110786dcad6b374d976d91b3957b90ed95b818333780efd52b6e577aaf30118de0dc1bf1f12a15928678b91637d6127ba3dfd303b15c9edda2f3fb341fe30d71ca619bca82b14c7429630c06aa498a2e1fa83110cbe47a163d8efd97145e32cbb559876ebf11b9e8415f6a30069c566e607f5aa0b7109d284e219feab6693b773bc326c5513cceb6fcf7beaf7551643f60ae0e00ccaff9a32bcb22afacff62aacf222f6f5ac67bffffa3f730d07c7342418e0a59da065852068cdac943fed6fb3927c1c9fc1f49413ae56f4677f1a0c9247029e5a5739423ef94169189f335639e8afce14bd9f687a4478a6526ec8d61da24a87406b03a1d09a81db328ccde17c2c2fb10ae10f3b2bc3964e1dac88a89be67d40d79db8afdbe5ccecefd73b0a24386631b3aaa0993cbd59e562a19da640d867d2ee4f42f0bab11ac92e3bd68ff675cb54a2d05c0fd580f19b1a3ac5a3ffccd1fe756a006b7fceed1e6f5279c050cc75c66bae17ca7ee17485c6b67df579746f8d9bb1cf81db8bd9c87769496d09cb85a1a785c50c9c232b5f61b527c76380723902375913106012080a4c000767d0fe66add853a6d167f92d10b6377d2d3c866c828950a2b5784ccf856095196a8413497f33807e52b8098484016c78a5c4ce895ae10ffc37735bad831b1e9639482bdab74bbaddeeb82ea83b3a0d4039dbdc8c7a17145d8bab91106ade6dbdc44f03044a53cf01b56505c93e81ac437a8dd56f2ac12adcf9517a4da0b626eee553547744f213d575f081b8e4fa05c35f8d60a15af71dd2423e1321c18045ae6f07dc372c5f98ac17d8b40a49338024fa0ea65bc815645e5e4b4cebe40758efeedd11a3efa8c8ae62357a993b7c8db4924f87205e6c44db21c6f3ba967f0e023c0c4181dfc0c119d0df26854171391aa7fa9ab1ab02998adddbb3e96b0684acf28538178238f627db5aa54108b0f9796e28fc679603f1bc2f159993700bf99687a7dbee81c6d3d35cba3fbfc4949824180ccefbbb596b6aabbf62221a032f1c57190b6dc9c2d48e0c08d736893ca44f0adf407e66fecd43af411cb1ced3a764a716179ba83f3b7fd6f640c280816233fd25f1d90dd73722d5959ec426f89e588e9c8bc6e79266d3906908baeb8075c127a5eaeb3b970d5378c1b9af0e6ef449cc7d31d31b0c95dab6ece06abbaf88003383506006405d5320a7f94e43b1239696546fcd4012d7fbb4d267a485f731f8dd9dcaef1986fcb02fabdaeb3bdc036487699cf54ab420da5a6267d806535f224be75d2e52f5b713d70158a539cec0431ed02fc2ec0f174c0d64f3bdd2ff40f53190b820809a33c4cb65a7efb295dcec79198642820143fff7a7427719b1859044e20f6f59f177219e7e92e3136e70b39c9c0c0c7de60f70ad5bb15d568ecec0ef625220182630c12c5d095a9f4f805526764e852adfa841505c01a1285400e415f3a5d055c3a4f8ad7e97dbe1398831b9969ba4371fd7f9bdcee1bc7276ffe087d5548322ff8200f3a0c09c702c8a6388374dba6af52fbe43bcc9029d721202dfea1f3d867853798c92eb8fb1d5eb2775ae70a81de0f3cab3a0bf7aa7749982a8a12029433b5437f0fd85be9ab7599d97e947cb1487810b283c59cab4508acfd59917d3ae845347f99b7b2759936261929e37d3ee729b42605040501824ffc55ba0f98db780b140f41dde027ac6c9790bc7a101d063aa286827ad92601c17b54e1855a5ff4a94fd17aa1c27e6456868689c8417f14ff32ab054b5ae6a9e445e46e68aca09e431fe615ec7dfdd7fd4fcd02a302db38fb20d2cbae223f7076c0476d4fe00df9b7a7854c500231a87ff28c8101ac10b3fe9fa81ffa7f723c1402e5545597a1a2b369effe3c8a117659db5b8257d9e1b5d44cbb1fa34cea277ee03572bb40fd678a37dd96edf9b0c7dff76f01ac88be541937a5668f0d5871f1e88ac22b0622028ac483838034ee2fb3b7601ed5667373784462002b5477f23b569e066bcf63c0c81c5fc5fec829e5a0a374a723f279ff361f2cc59287e99951ebeced8c6732b2df2bb109ca3874d087ea6273a6ce6526058dc5f67448178b2b86a595d9cc94186a181cfcfe2399f5475b2ea3be498b8846e020283c060f0d71f2010f8b7ffffc4db10f037b30b90278c3b267f73f5f464ec815ca1aca3bad317f282fee6f1932f5059525262c25fdcc0dd3081d2393444a1574c572f0d8f7c94984925133dc36d5904bed87d93cebd89c5f7a917fe991bb0c59e2bb26317d489d1f9943ecfd729f0303833f58bdb75cc57883e53fc0011bf5eb95d6cbe89b6f9393116b76b59547706c14a19ac83543154277bfb564ab5baa8b7c97a7ac5217b9d858b83e4cb6ba26bf17a35bb398fd824985b5f252679bc9e24e27c2a5e16ad3f4fe4765a7279fe3c1bf0994471e203ea41be83030e58823b527d225d458f19fbecedcd8de87c48a0549d222d1abf6da7c669f69d01b91b07cae0e45d8d82f9173a8dcf493f2e7b25b68b5c2c6e14ad16d84f83c52cc5040a8ccba58bdf6bbbfbb2742659dd757afc05d7d5ca04941bedf80dda0936a3cc0a7ed2d3b4add5edc63a5329cf83ce7c5606e9413957e29debc0d6c951a1bbc361097e41d2a9a102cdfec48d5fb0b5b81564ba859a922d3d07b19c90230e428aab574d85dd2a94d09766d0ed5faedd1adfeb9570d4124cb9499ee5ba5f839fd4a0509d31e87a79f75a8fbe68d945d0ecf36ef5fe51ada53bcfb8a8e2476e359bbf37379a655cf94c3981b714358242c3f32677649be0006311d5253344a5b4892516e04513e15a1883da273069a822a5f4786542df1013c0c999ca083e88ef8727bd7bbc965ddaa76e88ffaabfdff0a1b1f9a87eb96ea5e09341d316ba0b6503486ae18fa621aa5da139656a1ccf5c54c9fb5f359894b3de3ac733a25af7b6c0053b26df5a4895495314ade845ed0deb963175c983f16ee79c9a41aa0ae28bb8a24920b3b6d3d7af3cc4929d4118ddad387def3e65908fde6b822689498525df2ef134dbe90f771c586b3034ae6a55870d16f45fdf1633f7c1e5c424d48a488c3f907d60f3c5278eba86e55eb72e61997b7c495963c7e952cd1dd37ef3aef33b868da15d3783c7c265c4dbe245fa99b9f4e68458046dfc8fb35fed990eef5d52cfb04f6a17d16e6aa27d627e72abce9615ddb1afb4c74acb80bd575ae9d512c2503ba6225dbbdcf449e46a55b2b7d2d594c699a227f19e6186b92c7cce2fdc75f9d36ecf3c9ae9fb5c6a153443d670ba23a576af7a6b4ed996014aef53511cc0694868b24426844d10819365465f7d4d672f23308c082e4041fafcb56ba1715ab8094662cd1d3d34c286bb8a5c282ce70716c5d1f507cce7dc4cb3bb7588a12f30f1121fbf336e2861b2f227dab7cad82e622b791565bd620791c360937352addb2671611eab2aa89a6b9634d77f75a6ff4e33c98709642c43631a498d44a846558edeeeb56a1cb3e0180526d72c3a3ba14ec4fb6c9b993abd05b1f9d873c38e9381fb9bbba9d9c1083df8c77b06861f4a82100433d10c0b60ad77413b6411d20618c56c1f3f6320ec27232252f330a6d8daf6aec220fc250b4dab72b537b2d492ad9b13d928d36b28389e39a76a7657cb3c09f5e78ba0342eef0f73ed63a0561230e810b6f2276db7a8a07421e77a92238bb67f7a84c418ac9b31a96e6a66b83a176f82f065d352cf1e12e0787c97de796d8d5ae7d1bda25d2fd6725f1601fecff31ee12d986a34b9793031d2ea9e57f44f2ca33e3a25d69aae9b0986d61110eafb12e7f1bd21043b4489de15fd2470a6228eb985dd3ddf65d18ce551f60d576c830df6ed55ec68bed08a8377815ca5d8c60173e49ece77ebda3a6f6e5acd5c04e1f8a449fa734648ee2f4d609f03b5256c16bc627cb375e7dd86673b6f2e1bb19a3d8d6bd46b2d8dab9fbc65f4e1aafe24089ec2a71f75bcd21a53982cb0ed95e8eebfe969ecc67c414bc0e4d2132ae9798e38516243bce6be637c9b66ac1c0fa73c89fcb566e47a4bb08fa73981c3db67d90c6d6bcc77fc053bcf0483f2c85a6cb0ad92359aae476e32c877f344c0b02fdc1f52f496057b544ca7db23fdae9c478281fe669f3bed6f9eec6d139a18d4775c062226bc5dce2e48bcd2ccbe4755e9bb8c0b90617644e571751a70bf5dce4fb8fca277aa85e8545cf288ce408df4c0834f114a875008e32114a204fb1e1c88bad358f1fbfd61185bb827319e91d969555fbd44cf2c98c72f99f7cb783eb8d1f3ba51c906120c50cc61ab113f2fe9260d223c55ff3a966ffda11a4c7d5a97eabcc8268d0ac0bd0578b088d409574b95bfaf2c8e77092acb20d074cda1114886f17665906ff63d59389cd2212317eaaff9a308279353afdd97111acb1577cc01d46be10072bb30e017114e7c91befb381dac51d2481890c62c9041367a99b3bb9ccb2667d58b07aa30fb487a704650fa7d4a37ab03e62740ba788c9651f8f11ba91e2efd218b09f839ffe0489de7be914ebb76f38a2a67aabe551eb90f89250d447f07b1040da1d51a2f4b08ddfc99dc4adc4de4a6f11ea361cc15026a338c8954b29bcec03195c1bf9423f4a7275b6080cfea76dff87de52b6207a7b2ed17c299dabedca02eba7cf93691d2482a85660f2fa06f6c0392f3d4aa4161e0cc8ef0592998a474451a8b46b8edee77b9cb2570ba7dc395c187b8b271df9fe3ca4c133330b17f1057a67ae44e4e7a9d9ca2cef33e46dcafe0ca6bb84f84be98a565c67f80fdafc095bd170b067ae60320906b91d1056bd939c68e2c66ee7afaf679fa1705ccf35bdf03ec4043b3b105dad2a34ce99dfc8b8b44a04c3d745d2b8779e5fc07bb9f99e2d20ecb59e4dfca597f4657ff9372d69ff9921f286739dd3bd8bc3420654d5c48bc6c7c0e6df50e9e0b4be7fa18d1f29d9cbb79b6ece100189c89c52dd023aa14f7059afaeac6ad4f531112ce5d9033caa5aece6fad86062a6f41f66cbfbe40daeac0fe75c2c17f7a02192dccbd577680cb38acec9b69cd18634d6e4edd420c832161c0a49a4d583c052cb5b83e4a2d58bb8a17e335736174e458481716667cf6f6802c40d5dc908ecd31ab1fc97ca658b0bc86cae0a930d78c2c58c56683cbe51c7b212d024c074281a901e1e58cada91a2ee1e5e19dd08f1937197756f1bb71448c9e95472f0e4faaddb5f96148f9c55e67e5abbd36e57ff92fb1b41f8d33a6e74a83039d2c5ad5a72c845b2051e81d5765c67fd129b33f9d3cdf713646070487da02dd971c15a7b2499e67bb0f613055e816ce78f65773d450352e07f1b689c5f97802ece42ff1aa4c4fbf35947fb407ea6b0c1acdf1259bc756e19258dc09c42cd27e8880e88250102d209470377659ab3b3ae554717ccfc2150fa157352dae5707562fc5e16327d07f11fd6105215110f443cc9df23f80b9d71cf306dff0f763eeb640b99d24daa9f41291b3d737abb3286892e3b6ac29fb58956fbfbc757543a5995f05b8a45a3488c7593de5e9286457eb3f26d57c7e583585085395ecd62d318dbd8180ff7f45134db0f147e33d85dfce704577dca69c12d6580afa925b4c81a4d62fa73022b1d4d1e15ff09060a0d27dba5da9edce1ec70d77dd1cb63209ab1e203c51297f82ca5ba78995b9a60d604d164d34e51df2a7b2ee8d5a7d742eb720dd0b47e693b68235a6c97ad51b417d04fa07100a7d01f8c412bd7539cf4ab065cf904d0178ed48e629e965f75ad12393289abe58c096fe872dab01859ef47bcecbb97f735ec03df6ffcf705e0a2c3e573b023c0dc2771d4522434bd412c4709160a0fe693a4e2905f5fe66ca02acf6e5835b91371f31cb101270fb3c616b9e7ca136089c531e1f7c7557dd386aa9b2b58d97eec20ca68c626625dd44c04444e4b33e99a46fd997dabf2f1280ff30efebb84b277ea66a0ef14767574e66f95e3ff8ca28c1aaec34f8bbb53488571c6682a8eaf2f7e4557d0bfcf4e5c07f0877ae77e6efba46d07b7f30ed1e24336d9e7dfdce27fa98ecae0e090324979c83a0bee83d6d7a29b89c1b372d241ff025640730ab180f267f1ed1ade1034e5f5ebd65386d594eb36bcdc5472ed356947c856d2d4d3510bca7b3102a9b10fb4deba70fb58ec9f44b47eb4067808f0f6210dfcb49c10a070d19c5ce690f7f26e7ad1888f319e76916b7cb8b60141fcf3397ce88b538462b433f9316fdca1d004830a02412d346a99706ec97be3a7846ed54324b20eba95887b875bfe96c87de74953e70f303224da5d7a808d6d450b43a8511a3cd2e96af7c390e5bae75dac0575afec237ad139fec0c3d5ab364677dc8f731523436c92b826b064a963fa3f5996d7badd135aa90f39467a7f277ec6733e868308ed17af6dffea601067a4a2a44a86985bcc25293d8683511894a8f9fe859326faeadc767c533b6b65c011c9d031cace471ed98ea43d8b674555fa655be4e6b7b4b0e36c279a2f0c981de0f81230342e14800a765b294d56eefbf1777ffa876bd71417a90d236458ea8824d88aa7d3ba57b72f287fd7d130a7bf5dfbc7899435e3c5b1e46bb8a569ce3e4251687ed374f9df2c446ccfe53bcf893b1a3fe207ca7d78b87ef4549c64a8b9f29a159eb2c084d770b1d0a02434ef00527e1c5a33d5fea3d5216313c0b3bb21f650b3a41ffbf145c698b7c270ea49d3f4ba0ebc19c3294e11f39c1419ce6900ab8d56bba27391b7e6a7739e7966ec555722bdbf88967afb7e91cc59a95cd442b58b30844941e637fdcf30d3eb86f27cc7e0853e985f22c960d134b59d4e769633ef72a4a2d6c17b19d341161bad0a990b68077011bcd349ffcce8ec0177324daeb7b972d094a53c8233f4bc2a176c06562b377f4113afbeae119bc94a3818973cd1af6fc3397ae38273d78843aefcb0db866ca04bdedea5bb920ee26dd5039da484d83414651e8876e8f83345da3ce4e3e3469659aff33e9ff33e9ff0926edce2d30c8708f746444d16ba0a25a898eb4472be081a09f6febad7ec537899030e08c7e5735dde0edf2f6576b985c9728081e531f34b6f33e13b53123a598348be9fc167031ff7dfcaffeef393376b9a3d8f8494befcf045c430252d70fa8ece935393055a1961f4426709deb98803bf75706dc7d1166b4b2f8bd48616f2fce1bbd974da57d3d3c9060806192fa5a3ea509d33a785aefad90b9b25bd5e9f4898964168de0aea22dacf68780d525394880fefdc54a3615934c61f705cbda67b614535637fa696f926c8177f5ff1d1b650f1d49cc67967aa6b03e56652d166cd6e7564512b0d9abff0b1d09c60e7a020d136424f3ad7a55ebb3951d10b4770afc0f9e193b3b109fbff60ff6ff4bc17b716346ea0ff0e625e8b0da80d9826beec20d2fb97ce79decc2cf568a39a945735ff763d07d99c7d94bdf571ab5f75953dcdc5d9c3639bf45331a2cebe4a47ff6b8e75f6fc492b7b3711129ce96375bb1305a0bf1b8b15ec364732dfc92e4106b802c816a4e58ec2c1165a06a9f0f4a49575c8c2668fe2d0e1c113e274c987db760f3de5747c2ebf84252a254e60bf7b446a03755c3bdd228706245c98bd307e9818a7b966a0180ec5a3239a5697c34e24c32450ab7faa587098de18c6ed01c1dac5a1ca69ab22404161e08858505a8ded5bf77bbd542d6d75bbc7ea87008ea831b2449a593f4149a3dc2258041f9ccdfaf770c38dbd8a728716e3621e84370514d1d21cdae547df0f9eda10b34206d88562ca5d6d71cb20585598580524050d0dff88cb4bff119210f67bfc36784fc057cc663f97cc7f152a4ff4a78fa4f9af40931917f9acf07f99bf96c473effd87b8e6aad784f38fee3f95c30e0141a706a18abaff639adf886d9a744ebe4d0f79a17b9992fb818d2072b91b97103964a0fb1583078b702176ee30776dda537ba22761791d5e286e478309bd367f8f210743c7c4b8636c9fc28e878bf32732099abc7b7e8e38a8df2fe686b3b46fbf55f05840e6f0d42c28051877bfa821b3707e8607bbb0107e65ae5d2a34fe77b3f64829f39c7142fe56301e2568e8ab7c105a7a45611b28967e37734394c6f4546cea5e46cdf25c1c48b26f89689709cecf43a588ad786197bff8825e02ac7aa7872fdc6cf388a5a29a1000693273146c28496c1318222b323579d8ec944e6ffca4ce43b1711c819cb7da9a8c336ca709276d3c46f778ea87d82df4ab36ab062b1a1533b413902b07881b83eda6b149ef68fb7b9a5a4428b82e9d5550ba0c69939dd0cd3e4fd22fee3a7cb0cd5aeaa70132ee962ad649ea9b7b054f39dad500ac554a4e998c18fbc51ce6500306ac7c75e1bb49a1a7d8e88e50b1176cdbdff6a419c3d6ff19d649f4147afc1c8a1e9e31ee2edee1e3f6afad9b40da13077d15c7776cd97e3c8a759f936184abf8ab71fde6cf9754ae8626335d02d038191f00714b799f0674a3cdff5ccb97bd6633eab1b665c5e05ac7a6df898fb6054b8991acfcb2fcd5f7e17d76bc0c525b1b429ddbe6f9a26e0f5df0e84f0acfc6875ea517772ea633a6241ca16656c3d38ddf3f7629c13bfb89b8504db0a9a47817f4d497ceb2c3fe0acffe16cc33d4f6e0251ab902252aae8e1dac250915c83fa30de3240ea80313addeb0ba262153dc89f2f25660394aa4fe41fc2db5bd85cbeb3dd2f8980b28050504600477d5d2f8cf9d12d9e19f237c30267b02fb9e7536e3f0a9fd097101337bf8642fe703ad08a82f4fd3b6d963b4c9bcb14924ab1f71b48fd726b79f12e10819024cd81ff0bd3e6ad71b05ab497da70d3f29ba79d9b417a2068ff1ee49fbc6a81c4c41def9fecffaa60ae3c254915d6623ec5442d0bc3863b72b1b0ececf5eeb7dce11ce98253fc3566f54a184e76978c8a93a885e679aa9d10e6516233163a617cd97633ee2002178fe39e4fdbad33a7fdcc5b0ebc2f9a7bb73b3dc6e686bab9490c17fa422fb8e3cc763abe78608eb5d4174291e4ad1cd0c5f11511541c13c72a85cd470f667fa89fc4cbc5af69733af1c88603ee41e6f940bf7900ee7ffba9d72734a47511d267c85f65c9b3761b709de9bb152206d3cc2b26d7cd31c95960dbb96757d4e655dff6f8859cf2a04d2302da0342413b0090f18e87c552901a05fb79c612e194b56b7dc190cbd26778014f6782678d1c0a3fbc4fda51509f6fa194e7ff0dbece87ff005f87751a0fadd885d531a699eb0d2153aff1b0bc8a61475222bb9d8fe0fd8e97cd2f003152226e5a59c945ea4778574dc85d7c5d1f0b39195ea5ed21a887ac5fdfea4aab8c80ec3d848333e80ed93ab4817f7eda3723a036fafb17816008755791be1f448201e1bd9841eab1f36c3a2fcfdc99f43a63b0d898d3f4666579bf2b924809b4782613c0b6631a7aab9e7670c99af8eeeb38f7f1070fde8adf9368c2e87ef9d1785f2336fbbf5f0ff98bd594bfc50eea7c140d37a717f36a840deb650856d7838cc9328fb183c5ff801ddca6b8f52c9ac851ffe6ad85328b9d6afb81aefeee878bce0e46da5ed70cdbede9015bfe99c6d2acfd6ec30f429728922a7b32232a26bad3ddc22d705f4c309d66bb707864f475570784c32a9f2d2ec86274ccae2334b4bbbf539cd7f2e2c30f45c52a865cf77e784b777c3b324af1f33cc90dbad3db0cf8a27cb28bd3a9421aee700f0f22d79f2910ffbe896e860bab60400d9130e0cce36606c757cfb5debfa61afe24a6cc8f24f7794910193e6a443f87e614bc150098ed14301592b08cc774053fdeb4a3bfc4df938719e25076f752f39916efd2a0290494088482e201b5f81ebdc46b48a863d9506ca146b4653dfcc27e73fc0d74729233ee75a9c2bb3faca62e14e4c5ef49069cffb32fd620e782bc9c50de81fd5ca6405ad4c775eb832917a6913c3346cb1cf7430e352f240c90ade27aaf3437b9d8a9b9724e339d7a5d3fb391658e8747a93ccf39b2fe222e2f80867589d4e7608941037e752ea05a9683d8a4629a9f7ce4b543f0c695832f59c187ceebf0ea72742de668448d63a55aa6f06538d70c43d01474f74cb8e21558467900e71f528b5882617c8aad41fc1d0c76628f3733eb1362e11791308051867b8d938642e1fe0eb619ff1df6b5e0a4000a8a2eaea7b1116d028fc67a7700d38035bb17f58bdd0cfbe73870e3de4da1c5fbd1ca6259abd2305a17af5f23cf3abceac3e2f015f7de0f5ff5b136b825e7569acd32b543acf1f613de45656cdefd5fcef341184402b292c72e131206500c4b5899b1f990977cbc41530bdba72e35b99da519db475b686353b36c1c6406889bb46c983e4526060736b41a741a1bc5ca549b0bc7c96ff0acb796b4f32efafd7f010000ffff59773022", case: :mixed)
      # parse_frame_sequence(bytes)

      reorg_monitor_task =
        Task.Supervisor.async_nolink(Indexer.Fetcher.OptimismTxnBatch.TaskSupervisor, fn ->
          reorg_monitor(block_check_interval, json_rpc_named_arguments)
        end)

      {:ok,
       %{
         batch_inbox: String.downcase(env[:batch_inbox]),
         batch_submitter: String.downcase(env[:batch_submitter]),
         block_check_interval: block_check_interval,
         start_block: start_block,
         end_block: last_safe_block,
         reorg_monitor_task: reorg_monitor_task,
         uncompleted_frame_sequence: %{bytes: <<>>, last_frame_number: -1},
         json_rpc_named_arguments: json_rpc_named_arguments
       }, {:continue, nil}}
    else
      {:start_block_l1_undefined, true} ->
        # the process shoudln't start if the start block is not defined
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:batch_inbox_valid, false} ->
        Logger.error("Batch Inbox address is invalid or not defined.")
        :ignore

      {:batch_submitter_valid, false} ->
        Logger.error("Batch Submitter address is invalid or not defined.")
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and op_transaction_batches table.")
        :ignore

      {:error, error_data} ->
        Logger.error(
          "Cannot get last safe block or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check op_transaction_batches table."
        )

        :ignore

      _ ->
        Logger.error("Batch Start Block is invalid or zero.")
        :ignore
    end
  end

  @impl GenServer
  def handle_continue(
        _,
        %{
          batch_inbox: batch_inbox,
          batch_submitter: batch_submitter,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          uncompleted_frame_sequence: uncompleted_frame_sequence,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    # credo:disable-for-next-line
    time_before = Timex.now()

    chunks_number = ceil((end_block - start_block + 1) / @eth_get_block_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    {last_written_block, new_uncompleted_frame_sequence} =
      chunk_range
      |> Enum.reduce_while({start_block - 1, uncompleted_frame_sequence}, fn current_chank, uncompleted_frame_sequence_acc ->
        chunk_start = start_block + @eth_get_block_range_size * current_chank
        chunk_end = min(chunk_start + @eth_get_block_range_size - 1, end_block)

        new_uncompleted_frame_sequence =
          if chunk_end >= chunk_start do
            log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil)

            {:ok, batches, new_uncompleted_frame_sequence} =
              get_txn_batches(
                chunk_start,
                chunk_end,
                batch_inbox,
                batch_submitter,
                uncompleted_frame_sequence_acc,
                json_rpc_named_arguments,
                100_000_000
              )

            # {:ok, _} =
            #   Chain.import(%{
            #     optimism_txn_batches: %{params: batches},
            #     timeout: :infinity
            #   })

            log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, Enum.count(batches))

            new_uncompleted_frame_sequence
          else
            uncompleted_frame_sequence_acc
          end

        reorg_block = reorg_block_pop()

        if !is_nil(reorg_block) && reorg_block > 0 do
          {:halt, {if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end), nil}}
        else
          {:cont, {chunk_end, new_uncompleted_frame_sequence}}
        end
      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if new_end_block == last_written_block do
      # there is no new block, so wait for some time to let the chain issue the new block
      :timer.sleep(max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0))
    end

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block, uncompleted_frame_sequence: new_uncompleted_frame_sequence}, {:continue, nil}}
  end

  @impl GenServer
  def handle_info({ref, _result}, %{reorg_monitor_task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, %{state | reorg_monitor_task: nil}}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %{
          reorg_monitor_task: %Task{pid: pid, ref: ref},
          block_check_interval: block_check_interval,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    if reason === :normal do
      {:noreply, %{state | reorg_monitor_task: nil}}
    else
      Logger.error(fn -> "Reorgs monitor task exited due to #{inspect(reason)}. Rerunning..." end)

      task =
        Task.Supervisor.async_nolink(Indexer.Fetcher.OptimismTxnBatch.TaskSupervisor, fn ->
          reorg_monitor(block_check_interval, json_rpc_named_arguments)
        end)

      {:noreply, %{state | reorg_monitor_task: task}}
    end
  end

  defp get_txn_batches(from_block, to_block, batch_inbox, batch_submitter, uncompleted_frame_sequence, json_rpc_named_arguments, retries_left) do
    if is_nil(uncompleted_frame_sequence) do
      # there was a reorg, so try to rewind to a full frame sequence if the `from_block` starts from a frame with non-zero index.
      # if we cannot solve the puzzle, ignore the incomplete frame sequence and find the nearest full one.
      # anyway, once we find the nearest full frame sequence, we first need to remove irrelevant items from op_transaction_batches table

      # {deleted_count, _} = Repo.delete_all(from(tb in OptimismTxnBatch, where: tb.l2_block_number >= ^l2_block_before_reorg))

      # if deleted_count > 0 do
      #   Logger.warning(
      #     "As L1 reorg was detected, all rows with l2_block_number >= #{l2_block_before_reorg} were removed from the op_transaction_batches table. Number of removed rows: #{deleted_count}."
      #   )
      # end
      
      # todo: ...
      {:ok, [], uncompleted_frame_sequence}
    else
      case fetch_blocks_by_range(from_block..to_block, json_rpc_named_arguments) do
        {:ok, %Blocks{transactions_params: transactions_params, errors: []}} ->
          transactions_params
          |> Enum.filter(fn t ->
            from_address_hash = Map.get(t, :from_address_hash)
            to_address_hash = Map.get(t, :to_address_hash)

            if is_nil(from_address_hash) or is_nil(to_address_hash) do
              false
            else
              String.downcase(from_address_hash) == batch_submitter and String.downcase(to_address_hash) == batch_inbox
            end
          end)
          |> Enum.sort(fn t1, t2 ->
            t1.block_number < t2.block_number or t1.block_number == t2.block_number and t1.transaction_index < t2.transaction_index
          end)
          |> Enum.reduce_while({:ok, [], uncompleted_frame_sequence}, fn t, {_, batches, uncompleted_frame_sequence_acc} = _acc ->
            frame = input_to_frame(t.input)

            frame_sequence = uncompleted_frame_sequence_acc.bytes <> frame.data
            last_frame_number = uncompleted_frame_sequence_acc.last_frame_number

            with {:frame_number_valid, last_frame_number + 1} <- {:frame_number_valid, frame.number},
                 {:frame_is_last, true} <- {:frame_is_last, frame.is_last},
                 parsed = parse_frame_sequence(frame_sequence),
                 true <- parsed != :error do
              {:cont, {:ok, batches ++ parsed, %{bytes: <<>>, last_frame_number: -1}}}
            else
              {:frame_number_valid, _} ->
                {:halt, {:error, "Invalid frame sequence. Last frame number: #{last_frame_number}. Next frame number: #{frame.number}. Tx hash: #{t.hash}."}}
              
              false ->
                {:halt, {:error, "Invalid RLP in frame sequence. Tx hash of the last frame: #{t.hash}. Compressed bytes of the sequence: #{Base.encode16(frame_sequence, case: :lower)}"}}

              {:frame_is_last, false} ->
                {:cont, {:ok, batches, %{bytes: frame_sequence, last_frame_number: frame.number}}}
            end
          end)

        {_, message_or_errors} ->
          message =
            case message_or_errors do
              %Blocks{errors: errors} -> errors
              msg -> msg
            end

          retries_left = retries_left - 1

          error_message = "Cannot fetch blocks #{from_block}..#{to_block}. Error(s): #{inspect(message)}"

          if retries_left <= 0 do
            Logger.error(error_message)
            {:error, message}
          else
            Logger.error("#{error_message} Retrying...")
            :timer.sleep(3000)
            get_txn_batches(from_block, to_block, batch_inbox, batch_submitter, uncompleted_frame_sequence, json_rpc_named_arguments, retries_left)
          end
      end
    end
  end

  # defp events_to_output_roots(events) do
  #   Enum.map(events, fn event ->
  #     [l1_timestamp] = Optimism.decode_data(event["data"], [{:uint, 256}])
  #     {:ok, l1_timestamp} = DateTime.from_unix(l1_timestamp)

  #     %{
  #       l2_output_index: quantity_to_integer(Enum.at(event["topics"], 2)),
  #       l2_block_number: quantity_to_integer(Enum.at(event["topics"], 3)),
  #       l1_tx_hash: event["transactionHash"],
  #       l1_timestamp: l1_timestamp,
  #       l1_block_number: quantity_to_integer(event["blockNumber"]),
  #       output_root: Enum.at(event["topics"], 1)
  #     }
  #   end)
  # end

  defp parse_frame_sequence(bytes) do
    z = :zlib.open()
    :zlib.inflateInit(z)
    uncompressed_bytes = zlib_inflate(z, bytes)
    :zlib.close(z)

    Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), {uncompressed_bytes, []}, fn _i, {remainder, batch_acc} ->
      [first_byte] =
        remainder
        |> binary_slice(0, 1)
        |> :binary.bin_to_list()

      if Enum.member?(0xb8..0xbf, first_byte) do
        batch_size_length = first_byte - 0xb7
        batch_size =
          remainder
          |> binary_slice(1, batch_size_length)
          |> :binary.decode_unsigned()

        batch =
          remainder
          |> binary_slice(1 + batch_size_length + 1, batch_size - 1)
          |> ExRLP.decode()

        parent_hash = Enum.at(batch, 0)
        epoch_num = :binary.decode_unsigned(Enum.at(batch, 1))
        
        new_remainder_offset = 1 + batch_size_length + batch_size
        new_remainder_size = byte_size(remainder) - new_remainder_offset
        new_remainder = binary_slice(remainder, new_remainder_offset, new_remainder_size)

        new_batch_acc = batch_acc ++ [{parent_hash, epoch_num}]

        if new_remainder_size > 0 do
          {:cont, {new_remainder, new_batch_acc}}
        else
          {:halt, new_batch_acc}
        end
      else
        {:halt, :error}
      end
    end)
  end

  defp reorg_monitor(block_check_interval, json_rpc_named_arguments) do
    Logger.metadata(fetcher: :optimism_txn_batch)

    # infinite loop
    # credo:disable-for-next-line
    Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), 0, fn _i, prev_latest ->
      {:ok, latest} = Optimism.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

      if latest < prev_latest do
        Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
        reorg_block_push(latest)
      end

      :timer.sleep(block_check_interval)

      {:cont, latest}
    end)

    :ok
  end

  defp reorg_block_pop do
    case BoundQueue.pop_front(reorg_queue_get()) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(:op_txn_batches_reorgs, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  defp reorg_block_push(block_number) do
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(), block_number)
    :ets.insert(:op_txn_batches_reorgs, {:queue, updated_queue})
  end

  defp reorg_queue_get do
    if :ets.whereis(:op_txn_batches_reorgs) == :undefined do
      :ets.new(:op_txn_batches_reorgs, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(:op_txn_batches_reorgs),
         [{_, value}] <- :ets.lookup(:op_txn_batches_reorgs, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  defp get_last_l1_item(json_rpc_named_arguments) do
    l1_tx_hashes = Repo.one(from(
      tb in OptimismTxnBatch,
      select: tb.l1_tx_hashes,
      order_by: [desc: tb.l2_block_number],
      limit: 1
    ))
    
    last_l1_tx_hash =
      if is_nil(l1_tx_hashes) do
        nil
      else
        List.last(l1_tx_hashes)
      end

    if is_nil(last_l1_tx_hash) do
      {0, nil, nil}
    else
      {:ok, last_l1_tx} = Optimism.get_transaction_by_hash(last_l1_tx_hash, json_rpc_named_arguments)
      last_l1_block_number = quantity_to_integer(Map.get(last_l1_tx || %{}, "blockNumber", 0))
      {last_l1_block_number, last_l1_tx_hash, last_l1_tx}
    end
  end

  defp log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, batches_count) do
    {type, found} =
      if is_nil(batches_count) do
        {"Start", ""}
      else
        {"Finish", " Found #{batches_count} batch(es)."}
      end

    if chunk_start == chunk_end do
      Logger.info("#{type} handling L1 block ##{chunk_start}.#{found}")
    else
      target_range =
        if chunk_start != start_block or chunk_end != end_block do
          progress =
            if is_nil(batches_count) do
              ""
            else
              percentage =
                (chunk_end - start_block + 1)
                |> Decimal.div(end_block - start_block + 1)
                |> Decimal.mult(100)
                |> Decimal.round(2)
                |> Decimal.to_string()

              " Progress: #{percentage}%"
            end

          " Target range: #{start_block}..#{end_block}.#{progress}"
        else
          ""
        end

      Logger.info("#{type} handling L1 block range #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
    end
  end

  defp json_rpc_named_arguments(optimism_rpc_l1) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: optimism_rpc_l1,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  defp zlib_inflate_handler(z, {:continue, [uncompressed_bytes]}, acc) do
    zlib_inflate(z, [], acc <> uncompressed_bytes)
  end

  defp zlib_inflate_handler(_z, {:finished, [uncompressed_bytes]}, acc) do
    acc <> uncompressed_bytes
  end

  defp zlib_inflate(z, compressed_bytes, acc \\ <<>>) do
    result = :zlib.safeInflate(z, compressed_bytes)
    zlib_inflate_handler(z, result, acc)
  end
end
