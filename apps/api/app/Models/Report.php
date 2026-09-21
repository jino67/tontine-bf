<?php

namespace App\Models;

use App\Enums\ReportReason;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** Signalement d'une fiche publique par un membre. */
class Report extends Model
{
    /** Nombre de signalements distincts qui masquent une fiche de l'annuaire. */
    public const THRESHOLD = 3;

    protected $fillable = ['reportable_type', 'reportable_id', 'user_id', 'reason', 'note'];

    protected function casts(): array
    {
        return ['reason' => ReportReason::class];
    }

    public function reportable(): MorphTo
    {
        return $this->morphTo();
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
