# Craigslist.sol

This is a placeholder name! I don't like it either. Let us not dwell upon the bike shed's color.

Other/Further discussion (or monologue) in [this online shared doc.](https://docs.google.com/document/d/1ZrlJgmNP1jjD_2ZttNXKwkpXKNXg8kyvx4Kur3ePy6Y/edit?usp=sharing)

`tl;dr`

With contract logic, let's make it practical to buy something from a stranger known only by their wallet address.

As a buyer, you should at least know, worst-case how badly the deal can go for you. Smart contract logic can be used to mitigate any losses and/or assuage any concerns.

As a seller, you should be able to trust that you will get paid (the easy part) and you should be rewarded for your good behavior. If you do what was agreed, you should have a slight edge the next time you sell something. You have a "reputation".

Smart contract logic can be incrementally extended to do other things:

* Involve a contract-bound escrow service.
* Participants can post a bond whose fate is subject to contract logic. This can be used to encourage/punish behavior.
* The outcome of certain "phases" (e.g. escrow, haggling) can be arbitrarily abstracted by honoring the outcome of other contracts ("child" contracts?) e.g by calling `[0xCccCc..cC].getPrice(sale_hash)`, where parties both agree to use the outcome/return value of this contract function.

One _missing_ critical piece of all this: There needs to be a wallet based "chat" system that lets participants communicate in a signed (and probably encrypted) channel. This is "entirely possible"! Parties B and S need to be able to directly message one another, signing each message with their wallet key (even with a hardware wallet).

(For example: Create ephemeral communication keys via Diffie–Hellman but where the components get signed by each end's wallet key. [anyone?])
