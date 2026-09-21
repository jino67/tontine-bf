<?php

namespace App\Models;

use App\Enums\JoinPolicy;
use App\Enums\Visibility;
use App\Models\Concerns\HasShareCode;
use Database\Factories\OrganizationFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Organization extends Model
{
    /** @use HasFactory<OrganizationFactory> */
    use HasFactory;

    use HasShareCode;

    /** Lettre du chemin public : https://exemple.bf/o/ABCD2345 */
    public const SHARE_PATH = 'o';

    protected $fillable = ['name', 'slug', 'kind', 'plan', 'currency', 'timezone', 'settings', 'visibility', 'join_policy'];

    protected $attributes = [
        'kind' => 'standard',
        'plan' => 'gratuit',
        'visibility' => 'privee',
        'join_policy' => 'fermee',
        'currency' => 'XOF',
        'timezone' => 'Africa/Ouagadougou',
    ];

    protected function casts(): array
    {
        return [
            'settings' => 'array',
            'visibility' => Visibility::class,
            'join_policy' => JoinPolicy::class,
        ];
    }

    public function memberships(): HasMany
    {
        return $this->hasMany(Membership::class);
    }

    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class)->withPivot('role')->withTimestamps();
    }

    public function tontines(): HasMany
    {
        return $this->hasMany(Tontine::class);
    }

    public function invitations(): HasMany
    {
        return $this->hasMany(Invitation::class);
    }

    public function joinRequests(): HasMany
    {
        return $this->hasMany(JoinRequest::class);
    }

    public function cagnottes(): HasMany
    {
        return $this->hasMany(Cagnotte::class);
    }

    /** Espace personnel : ni invitable, ni listable, ni partageable. */
    public function isPersonal(): bool
    {
        return $this->kind === 'personal';
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public static function uniqueSlug(string $name): string
    {
        $base = Str::slug($name) ?: 'organisation';
        $slug = $base;
        $suffix = 2;

        while (static::where('slug', $slug)->exists()) {
            $slug = $base.'-'.$suffix++;
        }

        return $slug;
    }
}
