#!/usr/bin/env python3

import re
from pprint import pprint

def rx(s):
    """Turn a readable command pattern into a regex.
    
    "MY COMMAND <variable>" becomes "MY\s+COMMAND\s+(?P<variable>.*)"
    """
    return re.compile(s
                      .replace("<", "(?P<")
                      .replace(">", ">.*)")
                      .replace(" ", r"\s+"),
                      re.IGNORECASE)

def buy(params):
    print("calling 'buy' with params: %s" % params)

def accept(params):
    print("calling 'accept' with params: %s" % params)

def escrow(params):
    print("calling 'escrow' with params: %s" % params)
    
COMMANDS = [
    (
        rx('BUY <sale_hash> FROM <seller_address> FOR <quanity> OF <currency>'),
        buy
    ),
    (
        rx('ACCEPT <offer_hash>'),
        accept
    ),
    (
        rx('ENTER <offer_hash> INTO ESCROW WITH <escrow_agent_address>'),
        escrow
    ),
]

def dispatch_command(line):
    for pattern, command in COMMANDS:
        m = pattern.match(line)
        if m is not None:
            command(m.groupdict())
            break

if __name__ == "__main__":

    while True:
        try:
            val = input("> ")
            dispatch_command(val)
        except KeyboardInterrupt:
            print("")
            break
