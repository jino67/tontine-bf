<?php

namespace App\Services;

use App\Enums\Role;
use App\Models\Organization;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Espace personnel d'un compte.
 *
 * Il n'apparaît jamais dans l'annuaire et ne s'invite pas : c'est l'endroit où un membre
 * qui n'appartient à aucun groupement garde ses propres tontines et cagnottes.
 */
final class PersonalOrganization
{
    public static function ensureFor(User $user): Organization
    {
        $existing = $user->organizations()->first();

        if ($existing !== null) {
            return $existing;
        }

        return DB::transaction(function () use ($user) {
            $name = $user->name === null ? 'Mon espace' : 'Espace de '.$user->name;

            $organization = Organization::create([
                'name' => $name,
                'slug' => Organization::uniqueSlug($name),
                'kind' => 'personal',
            ]);

            $organization->memberships()->create(['user_id' => $user->id, 'role' => Role::Owner]);

            return $organization;
        });
    }
}
