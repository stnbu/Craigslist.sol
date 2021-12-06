
from hexbytes import HexBytes
from web3 import Web3
from eth_utils.toolz import compose
from web3._utils.transactions import fill_nonce, fill_transaction_defaults
from web3._utils.method_formatters import STANDARD_NORMALIZERS
from web3._utils.rpc_abi import TRANSACTION_PARAMS_ABIS, apply_abi_formatters_to_dict
from eth_utils import to_dict

from web3.types import (
    # Middleware,
    # RPCEndpoint,
    # RPCResponse,
    TxParams,
)

from typing import (
    # TYPE_CHECKING,
    Any,
    # Callable,
    Collection,
    Iterable,
    Tuple,
    # TypeVar,
    Union
)

from eth_account.signers.local import (
    LocalAccount,
)
from eth_keys.datatypes import (
    PrivateKey,
)
from eth_typing import (
    ChecksumAddress,
    HexStr,
)

_PrivateKey = Union[LocalAccount, PrivateKey, HexStr, bytes]

def format_transaction(transaction: TxParams) -> TxParams:
    """Format transaction so that it can be used correctly in the signing middleware.

    Converts bytes to hex strings and other types that can be passed to the underlying layers.
    Also has the effect of normalizing 'from' for easier comparisons.
    """
    return apply_abi_formatters_to_dict(STANDARD_NORMALIZERS, TRANSACTION_PARAMS_ABIS, transaction)


w3 = Web3()
format_and_fill_tx = compose(
    format_transaction,
    fill_transaction_defaults(w3),
    fill_nonce(w3))

from functools import (
    singledispatch,
)
@singledispatch
def to_account(val: Any) -> LocalAccount:
    raise TypeError(
        "key must be one of the types: "
        "eth_keys.datatype.PrivateKey, eth_account.signers.local.LocalAccount, "
        "or raw private key as a hex string or byte string. "
        "Was of type {0}".format(type(val)))


@to_dict
def gen_normalized_accounts(
    val: Union[_PrivateKey, Collection[_PrivateKey]]
) -> Iterable[Tuple[ChecksumAddress, LocalAccount]]:
    if isinstance(val, (list, tuple, set,)):
        for i in val:
            account: LocalAccount = to_account(i)
            yield account.address, account
    else:
        account = to_account(val)
        yield account.address, account
        return


if __name__ == '__main__':
    #private_key_or_account = ('0x6a8b4de52b288e111c14e1c4b868bc125d325d40331d86d875a3467dd44bf829', '<eth_account.signers.local.LocalAccount object at 0x10780f910>', HexBytes('0x6a8b4de52b288e111c14e1c4b868bc125d325d40331d86d875a3467dd44bf829'), '0x6a8b4de52b288e111c14e1c4b868bc125d325d40331d86d875a3467dd44bf829', b'j\x8bM\xe5+(\x8e\x11\x1c\x14\xe1\xc4\xb8h\xbc\x12]2]@3\x1d\x86\xd8u\xa3F}\xd4K\xf8)')
    private_key_or_account = [HexBytes('0x6a8b4de52b288e111c14e1c4b868bc125d325d40331d86d875a3467dd44bf829')]

    if False:
        # Dur works!
        from eth_account.messages import encode_defunct
        msg = "I♥SF"
        private_key = b"\xb2\\}\xb3\x1f\xee\xd9\x12''\xbf\t9\xdcv\x9a\x96VK-\xe4\xc4rm\x03[6\xec\xf1\xe5\xb3d"
        message = encode_defunct(text=msg)
        signed_message = w3.eth.account.sign_message(message, private_key=private_key)

        # Dur also works!
        # (if your 'ganache' has that address in its `accounts`)
        w3.eth.sign('0xcCd7d340F145A940cAd033e05926bDF79057DCa5', hexstr='0x0')

    #w3.eth.accounts
    # w3.eth.sign('0xcCd7d340F145A940cAd033e05926bDF79057DCa5', hexstr='0x0')
    # 0addr --  0xcCd7d340F145A940cAd033e05926bDF79057DCa5
    # 0key  --  0xacb069f18fc3733c9f748ba4e07f69311fe389c5dcd691241129ddbf40489d9d
    import pdb; pdb.set_trace()
    accounts = gen_normalized_accounts(private_key_or_account)
    tx = {
        'to': '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        'from': '0x91eD14b5956DBcc1310E65DC4d7E82f02B95BA46',
        'gas': 21000,
        'gasPrice': 1000000000,
        'value': 1,
        'nonce': 0,
    }
    transaction = format_and_fill_tx(tx)
    account = accounts[transaction['from']]
    raw_tx = account.sign_transaction(transaction).rawTransaction

#### ~/git/web3.py/web3/middleware/signing.py::sign_and_send_raw_middleware::middleware
#### returns this:
#make_request(RPCEndpoint("eth_sendRawTransaction"), [raw_tx])

