<?php

namespace App\Services;

use App\Models\Cagnotte;
use App\Services\Fees\CagnotteFees;
use Illuminate\Support\Carbon;

/**
 * Séries de cagnottes : une cagnotte récurrente repart pour un tour dès que le précédent
 * est joué.
 *
 * L'édition terminée n'est jamais rouverte ni modifiée : ses participants, son tirage et ses
 * gagnants restent tels quels, et une nouvelle édition est créée à côté. C'est ce qui permet
 * de remonter l'historique d'une série sans jamais réécrire le passé.
 */
class CagnotteCycles
{
    public function __construct(private CagnotteFees $fees) {}

    /** Ouvre l'édition suivante, ou rien si la cagnotte n'est pas récurrente. */
    public function relaunch(Cagnotte $cagnotte): ?Cagnotte
    {
        if (! $cagnotte->recurring) {
            return null;
        }

        $seriesId = $cagnotte->seriesId();
        $edition = $cagnotte->edition + 1;

        // Relancée deux fois (un tirage rejoué, une notification en double), la série n'en crée qu'une.
        $existing = Cagnotte::where('series_id', $seriesId)->where('edition', $edition)->first();

        if ($existing !== null) {
            return $existing;
        }

        $opensAt = now();

        return Cagnotte::create([
            'organization_id' => $cagnotte->organization_id,
            'created_by' => $cagnotte->created_by,
            'mode' => $cagnotte->mode,
            'title' => $cagnotte->title,
            'description' => $cagnotte->description,
            'duration' => $cagnotte->duration,
            'target_amount' => $cagnotte->target_amount,
            'min_amount' => $cagnotte->min_amount,
            'beneficiary_user_id' => $cagnotte->beneficiary_user_id,
            'beneficiary_name' => $cagnotte->beneficiary_name,
            'opens_at' => $opensAt,
            'ends_at' => $this->nextEnd($cagnotte, $opensAt),
            'ticket_price' => $cagnotte->ticket_price,
            'winners_count' => $cagnotte->winners_count,
            'prize_split' => $cagnotte->prize_split,
            'fee_percent' => $cagnotte->fee_percent,
            // Une nouvelle édition est jugée au taux du jour, pas à celui de la première.
            'platform_fee_bp' => $this->fees->rateBpFor($cagnotte->mode, $cagnotte->organization_id),
            'visibility' => $cagnotte->visibility,
            'recurring' => true,
            'series_id' => $seriesId,
            'edition' => $edition,
            'template_id' => $cagnotte->template_id,
        ]);
    }

    /** Une durée personnalisée reprend la longueur de l'édition qui vient de se terminer. */
    private function nextEnd(Cagnotte $cagnotte, Carbon $opensAt): Carbon
    {
        $end = $cagnotte->duration->endsAt($opensAt);

        if ($end !== null) {
            return $end;
        }

        $seconds = (int) $cagnotte->opens_at->diffInSeconds($cagnotte->ends_at);

        return $opensAt->copy()->addSeconds(max(3600, $seconds));
    }
}
