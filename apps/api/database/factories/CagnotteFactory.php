<?php

namespace Database\Factories;

use App\Enums\CagnotteDuration;
use App\Models\Cagnotte;
use App\Models\Organization;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Cagnotte>
 */
class CagnotteFactory extends Factory
{
    public function definition(): array
    {
        return [
            'organization_id' => Organization::factory(),
            'created_by' => User::factory(),
            'title' => 'Soutien à la famille '.fake()->lastName(),
            'duration' => CagnotteDuration::Week,
            'min_amount' => 500,
            'beneficiary_name' => fake()->name(),
            'opens_at' => now(),
            'ends_at' => now()->addDays(7),
        ];
    }
}
