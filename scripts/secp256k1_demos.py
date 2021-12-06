
from secp256k1 import PrivateKey, PublicKey

# make a private key, sign data, verify signature.
privkey = PrivateKey()
sig = privkey.ecdsa_sign(b'hello')
assert privkey.pubkey.ecdsa_verify(b'hello', sig)

# serialize and deserialize signature.
sig_der = privkey.ecdsa_serialize(sig)
sig2 = privkey.ecdsa_deserialize(sig_der)

# serialize private key's signature.
pub = privkey.pubkey.serialize()

# with only the public key, verify signature.
pubkey2 = PublicKey(pub, raw=True)
#assert pubkey2.serialize() == pub
assert pubkey2.ecdsa_verify(b'hello', sig)

print('complete.')