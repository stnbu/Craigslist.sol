from web3 import Web3
from web3._utils.abi import map_abi_data
from web3._utils.normalizers import abi_ens_resolver
from web3._utils.encoding import hex_encode_abi_type
from eth_utils import add_0x_prefix, remove_0x_prefix
from eth_typing import HexStr
from brownie.convert.datatypes import HexString

def keccak_abiencodePacked(abi_types, values):
    normalized_values = map_abi_data([abi_ens_resolver(None)], abi_types, values)
    hex_string = add_0x_prefix(
        HexStr(''.join(
            remove_0x_prefix(hex_encode_abi_type(abi_type, value))
            for abi_type, value
            in zip(abi_types, normalized_values)
        ))
    )
    return Web3.keccak(text=hex_string)

if __name__ == '__main__':
    print(keccak_abiencodePacked(['uint256'], [42]).hex())
    #h = b'0xcc7bf8047cc42408b0f5ef243862b29360bf96d80a3a4aa49e725322e824bc86'
    h = HexString('0xb10beef', 'bytes32')
    print(keccak_abiencodePacked(['bytes32'], h))
    #print(keccak_abiencodePacked(['uint8', 'uint256', 'bool'], [42, 42, False]))
