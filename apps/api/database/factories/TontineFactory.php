<?php

namespace Database\Factories;

use App\Enums\Frequency;
use App\Enums\TontineStatus;
use App\Enums\TontineType;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Tontine>
 */
class TontineFactory extends Factory
{
    public function definition(): array
    {
        return [
            'organization_id' => Organization::factory(),
            'created_by' => User::factory(),
            'name' => 'Tontine '.fake()->word(),
            'type' => TontineType::Rotative,
            'amount' => 5000,
            'frequency' => Frequency::Weekly,
            'starts_on' => now()->addWeek()->toDateString(),
            'status' => TontineStatus::Draft,
        ];
    }
}
