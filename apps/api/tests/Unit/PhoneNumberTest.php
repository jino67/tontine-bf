<?php

use App\Support\PhoneNumber;

it('normalise les écritures courantes des numéros burkinabè', function (string $input) {
    expect(PhoneNumber::normalize($input))->toBe('+22670123456');
})->with(['70123456', '70 12 34 56', '70.12.34.56', '+226 70 12 34 56', '0022670123456']);

it('rejette les numéros invalides', function (string $input) {
    expect(PhoneNumber::normalize($input))->toBeNull();
})->with(['1234567', '+33612345678', 'abcdefgh', '+2267012345']);

it('masque le milieu du numéro', function () {
    expect(PhoneNumber::mask('+22670123456'))->toBe('+226 ** ** 34 56');
});
