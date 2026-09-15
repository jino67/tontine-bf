<?php

use App\Enums\Frequency;
use Carbon\CarbonImmutable;

it('calcule les échéances depuis la date de début', function (Frequency $frequency, string $expected) {
    expect($frequency->dueDate(CarbonImmutable::parse('2027-01-31'), 2)->toDateString())->toBe($expected);
})->with([
    'quotidien' => [Frequency::Daily, '2027-02-02'],
    'hebdomadaire' => [Frequency::Weekly, '2027-02-14'],
    'mensuel' => [Frequency::Monthly, '2027-03-31'],
]);

it('ne déborde pas sur le mois suivant pour une échéance mensuelle en fin de mois', function () {
    expect(Frequency::Monthly->dueDate(CarbonImmutable::parse('2027-01-31'), 1)->toDateString())->toBe('2027-02-28');
});
