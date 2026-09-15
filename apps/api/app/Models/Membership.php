<?php

namespace App\Models;

use App\Enums\Role;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Appartenance d'un utilisateur à une organisation, avec son rôle. */
class Membership extends Model
{
    protected $table = 'organization_user';

    protected $fillable = ['organization_id', 'user_id', 'role'];

    protected function casts(): array
    {
        return [
            'role' => Role::class,
            'organization_id' => 'integer',
            'user_id' => 'integer',
        ];
    }

    public function organization(): BelongsTo
    {
        return $this->belongsTo(Organization::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
