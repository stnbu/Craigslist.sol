#!/usr/bin/env python3

import re
from pprint import pprint

def rx(s):
    """Turn a readable command pattern into a regex.
    
    "MY COMMAND <variable>" becomes "MY\s+COMMAND\s+(?P<variable>.*)"
    """
    return (s
            .replace("<", "(?P<")
            .replace(">", ">.*)")
            .replace(" ", r"\s+"))

def buy(params):
    print("calling 'buy' with params: %s" % params)

def accept(params):
    print("calling 'accept' with params: %s" % params)

COMMANDS = [
    (
        rx('BUY <sale_hash> FROM <seller_address> FOR <quanity> OF <currency>'),
        buy
    ),
    (
        rx('ACCEPT <offer_hash>'),
        accept
    )
]

def dispatch_command(line):
    for r, command in COMMANDS:
        m = re.match(r, line)
        if m is not None:
            params = m.groupdict()
            command(params)
            break

if __name__ == "__main__":

    while True:
        try:
            val = input("> ")
            dispatch_command(val)
        except KeyboardInterrupt:
            pass
