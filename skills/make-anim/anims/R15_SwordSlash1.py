"""R15 sword light slash 1: forehand diagonal, high right -> low left, snappy (34 f). Recipe in _r15sword.py."""
from _r15sword import slash, slash1_keys


def build():
    return slash("R15_SwordSlash1", slash1_keys(), 1)
