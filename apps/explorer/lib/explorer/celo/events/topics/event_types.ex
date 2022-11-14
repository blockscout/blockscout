defmodule Explorer.Celo.EventTypes do
  @moduledoc """
  List of Celo contract events. Use this module to have event values defined in context
  """

  defmacro __using__(_) do
    quote do
      @account_created "0x805996f252884581e2f74cf3d2b03564d5ec26ccc90850ae12653dc1b72d1fa2"
      @account_data_encryption_key_set "0x43fdefe0a824cb0e3bbaf9c4bc97669187996136fe9282382baf10787f0d808d"
      @account_name_set "0xa6e2c5a23bb917ba0a584c4b250257ddad698685829b66a8813c004b39934fe4"
      @account_url_set "0x0b5629fec5b6b5a1c2cfe0de7495111627a8cf297dced72e0669527425d3f01b"
      @account_wallet_address_set "0xf81d74398fd47e35c36b714019df15f200f623dde569b5b531d6a0b4da5c5f26"
      @attestation_completed "0x414ff2c18c092697c4b8de49f515ac44f8bebc19b24553cf58ace913a6ac639d"
      @attestation_issuer_selected "0xaf7f470b643316cf44c1f2898328a075e7602945b4f8584f48ba4ad2d8a2ea9d"
      @attestation_signer_authorized "0x9dfbc5a621c3e2d0d83beee687a17dfc796bbce2118793e5e254409bb265ca0b"
      @gold_locked "0x0f0f2fc5b4c987a49e1663ce2c2d65de12f3b701ff02b4d09461421e63e609e7"
      @gold_unlocked "0xb1a3aef2a332070da206ad1868a5e327f5aa5144e00e9a7b40717c153158a588"
      @gold_withdrawn "0x292d39ba701489b7f640c83806d3eeabe0a32c9f0a61b49e95612ebad42211cd"
      @oracle_reported "0x7cebb17173a9ed273d2b7538f64395c0ebf352ff743f1cf8ce66b437a6144213"
      @validator_affiliated "0x91ef92227057e201e406c3451698dd780fe7672ad74328591c88d281af31581d"
      @validator_deaffiliated "0x71815121f0622b31a3e7270eb28acb9fd10825ff418c9a18591f617bb8a31a6c"
      @validator_epoch_payment_distributed "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975"
      @validator_group_active_vote_revoked "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8"
      @validator_group_commission_updated "0x815d292dbc1a08dfb3103aabb6611233dd2393903e57bdf4c5b3db91198a826c"
      @validator_group_deregistered "0xae7e034b0748a10a219b46074b20977a9170bf4027b156c797093773619a8669"
      @validator_group_epoch_rewards_distributed "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"
      @validator_group_member_added "0xbdf7e616a6943f81e07a7984c9d4c00197dc2f481486ce4ffa6af52a113974ad"
      @validator_group_member_removed "0xc7666a52a66ff601ff7c0d4d6efddc9ac20a34792f6aa003d1804c9d4d5baa57"
      @validator_group_member_reordered "0x38819cc49a343985b478d72f531a35b15384c398dd80fd191a14662170f895c6"
      @validator_group_pending_vote_revoked "0x148075455e24d5cf538793db3e917a157cbadac69dd6a304186daf11b23f76fe"
      @validator_group_registered "0xbf4b45570f1907a94775f8449817051a492a676918e38108bb762e991e6b58dc"
      @validator_group_vote_activated "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"
      @validator_group_vote_cast "0xd3532f70444893db82221041edb4dc26c94593aeb364b0b14dfc77d5ee905152"
      @validator_registered "0xd09501348473474a20c772c79c653e1fd7e8b437e418fe235d277d2c88853251"
      @validator_score_updated "0xedf9f87e50e10c533bf3ae7f5a7894ae66c23e6cbbe8773d7765d20ad6f995e9"
      @validator_signer_authorized "0x16e382723fb40543364faf68863212ba253a099607bf6d3a5b47e50a8bf94943"
      @vote_signer_authorized "0xaab5f8a189373aaa290f42ae65ea5d7971b732366ca5bf66556e76263944af28"
      @voter_rewards "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"
    end
  end
end
