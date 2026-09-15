<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Prunable;

class OtpCode extends Model
{
    use Prunable;

    protected $fillable = ['phone', 'code_hash', 'attempts', 'expires_at', 'consumed_at'];

    protected $attributes = ['attempts' => 0];

    protected function casts(): array
    {
        return [
            'attempts' => 'integer',
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
        ];
    }

    /** Supprimés chaque jour par model:prune, un jour après leur expiration. */
    public function prunable(): Builder
    {
        return static::where('expires_at', '<', now()->subDay());
    }
}
