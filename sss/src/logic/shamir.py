"""
shamir.py

This module implements Shamir's Secret Sharing (SSS) over a prime field for
256-bit (64-hex-character) secrets. It provides functions to split a secret
into shares and to recover the secret from a threshold subset of shares.

Example:
    >>> from src.logic.shamir import split_secret, recover_secret
    >>> hex_key = "8d11e51fd3fd2773611133ab0f2d22938d1092f4f21f1b0b3e1dcb8cda6e4f4b"
    >>> shares = split_secret(hex_key, threshold=3, num_shares=5)
    >>> recovered = recover_secret(shares, threshold=3)
    >>> assert recovered == hex_key
"""
import random
import itertools
from typing import List, Tuple

# Prime p > 2^256 for operations in GF(p)
PRIME = 2**257 - 1


def _modinv(a: int, p: int = PRIME) -> int:
    """Compute the modular inverse of a modulo p."""
    lm, hm = 1, 0
    low, high = a % p, p
    while low > 1:
        r = high // low
        lm, low, hm, high = hm - lm * r, high - low * r, lm, low
    return lm % p


def _lagrange_interpolate(x: int, x_s: List[int], y_s: List[int], p: int = PRIME) -> int:
    """Lagrange interpolate and evaluate polynomial at x."""
    total = 0
    k = len(x_s)
    for i in range(k):
        num, den = 1, 1
        for j in range(k):
            if i != j:
                num = (num * (x - x_s[j])) % p
                den = (den * (x_s[i] - x_s[j])) % p
        total = (total + y_s[i] * num * _modinv(den, p)) % p
    return total


def split_secret(hex_secret: str, threshold: int, num_shares: int) -> List[Tuple[int, str]]:
    """
    Split a 64-character hexadecimal secret into Shamir shares.
    Raises ValueError for invalid inputs.
    """
    if len(hex_secret) != 64 or any(c not in '0123456789abcdefABCDEF' for c in hex_secret):
        raise ValueError("Secret must be exactly 64 hexadecimal characters.")
    if threshold < 1 or num_shares < 1:
        raise ValueError("threshold and num_shares must be positive integers.")
    if threshold > num_shares:
        raise ValueError("threshold cannot be greater than num_shares.")

    secret_int = int(hex_secret, 16)
    coeffs = [secret_int] + [random.randrange(0, PRIME) for _ in range(threshold - 1)]
    shares: List[Tuple[int, str]] = []
    for i in range(1, num_shares + 1):
        y = sum(coef * pow(i, power, PRIME) for power, coef in enumerate(coeffs)) % PRIME
        shares.append((i, format(y, 'x')))
    return shares


def recover_secret(shares: List[Tuple[int, str]], threshold: int) -> str:
    """
    Recover the original 64-character hexadecimal secret from Shamir shares.
    Tries combinations if more shares provided.
    """
    if threshold < 1:
        raise ValueError("threshold must be at least 1.")
    if len(shares) < threshold:
        raise ValueError("Insufficient shares to attempt recovery.")

    for subset in itertools.combinations(shares, threshold):
        x_s = [idx for idx, _ in subset]
        y_s = [int(h, 16) for _, h in subset]
        secret_int = _lagrange_interpolate(0, x_s, y_s)
        hex_out = format(secret_int, '064x')
        return hex_out

    raise ValueError("Failed to recover secret from provided shares.")