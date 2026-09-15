<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TontineMember extends Model
{
    protected $fillable = ['organization_id', 'tontine_id', 'user_id', 'shares', 'position'];

    protected $attributes = ['shares' => 1];

    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'shares' => 'integer',
            'position' => 'integer',
        ];
    }

    public function tontine(): BelongsTo
    {
        return $this->belongsTo(Tontine::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function contributions(): HasMany
    {
        return $this->hasMany(Contribution::class);
    }
}
