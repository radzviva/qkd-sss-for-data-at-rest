"""
 Pārbauda pareizu sadalīšanu/atjaunošanu

Nepietiekamas un nepareizas atslēgas garuma kļūdas

Slēdža (threshold) validācijas

Vairāk par threshold daļu apstrādi   
    """
import sys
import os
import pytest
# Ensure logic package can be imported by adding src to path
test_dir = os.path.dirname(__file__)
src_dir = os.path.abspath(os.path.join(test_dir, '..', 'src'))
sys.path.insert(0, src_dir)

from logic.shamir import split_secret, recover_secret

# Valid key example
HEX_KEY = "8d11e51fd3fd2773611133ab0f2d22938d1092f4f21f1b0b3e1dcb8cda6e4f4b"


def test_split_and_recover_exact_threshold():
    shares = split_secret(HEX_KEY, threshold=3, num_shares=5)
    assert len(shares) == 5
    recovered = recover_secret(shares[:3], threshold=3)
    assert recovered == HEX_KEY


def test_split_invalid_hex_length():
    with pytest.raises(ValueError):
        split_secret("deadbeef", threshold=2, num_shares=3)


def test_split_threshold_gt_shares():
    with pytest.raises(ValueError):
        split_secret(HEX_KEY, threshold=6, num_shares=5)


def test_recover_insufficient_shares():
    shares = split_secret(HEX_KEY, threshold=3, num_shares=5)
    with pytest.raises(ValueError):
        recover_secret(shares[:2], threshold=3)


def test_recover_with_extra_shares():
    shares = split_secret(HEX_KEY, threshold=3, num_shares=5)
    # Provide 4 shares but threshold=3
    recovered = recover_secret(shares[:4], threshold=3)
    assert recovered == HEX_KEY