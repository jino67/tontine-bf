<?php

namespace App\Http\Resources;

use App\Enums\CagnotteStatus;
use App\Services\CagnottePrizeDraw;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CagnotteResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $status = $this->resource->effectiveStatus();
        $prize = $this->resource->isPrize();

        return [
            'id' => $this->id,
            'organization_id' => $this->organization_id,
            'mode' => $this->mode->value,
            'title' => $this->title,
            'description' => $this->description,
            'duration' => $this->duration->value,
            'target_amount' => $this->target_amount,
            'min_amount' => $this->min_amount,
            'beneficiary' => $prize ? null : ($this->beneficiary_user_id !== null
                ? ['type' => 'membre', 'user_id' => $this->beneficiary_user_id, 'name' => $this->beneficiary?->name]
                : ['type' => 'externe', 'user_id' => null, 'name' => $this->beneficiary_name]),
            'opens_at' => $this->opens_at->toIso8601String(),
            'ends_at' => $this->ends_at->toIso8601String(),
            'seconds_left' => $status === CagnotteStatus::Open ? (int) max(0, ceil(now()->diffInSeconds($this->ends_at, false))) : 0,
            'status' => $status->value,
            'accepts_contributions' => $status === CagnotteStatus::Open,
            'visibility' => $this->visibility->value,
            'recurring' => (bool) $this->recurring,
            'edition' => (int) $this->edition,
            'series_id' => $this->resource->seriesId(),
            'share_url' => $this->resource->shareUrl(),
            'collected_amount' => $this->resource->collectedAmount(),
            'contributions_count' => $this->whenCounted('contributions'),
            'closed_at' => $this->closed_at?->toIso8601String(),
            'handover' => $this->handed_over_at === null ? null : [
                'amount' => $this->handover_amount,
                'method' => $this->handover_method?->value,
                'reference' => $this->handover_reference,
                'handed_over_at' => $this->handed_over_at->toIso8601String(),
                'confirmed_at' => $this->handover_confirmed_at?->toIso8601String(),
            ],
            'handover_payout' => $this->whenLoaded('latestPayout', fn () => PayoutResource::make($this->latestPayout)),
            'ticket_price' => $this->ticket_price,
            'winners_count' => $this->winners_count,
            'fee_percent' => $this->fee_percent,
            'platform_fee_bp' => $this->platform_fee_bp,
            'platform_fee_amount' => $this->resource->platformFee(),
            'online_collected_amount' => $this->resource->onlineCollected(),
            'pot_amount' => $this->resource->pot(),
            'tickets_count' => $prize ? (int) ($this->tickets_total ?? $this->resource->contributions()->sum('tickets')) : 0,
            'my_tickets' => $this->myTickets($request->user()?->id),
            // Gains potentiels calculés sur la somme réunie, avec les rangs attribués visibles de tous.
            'prizes' => $prize ? $this->prizes() : [],
            'draw' => $this->draw_seed_hash === null ? null : [
                'seed_hash' => $this->draw_seed_hash,
                'tickets' => $this->draw_tickets ?? [],
                'reveal_after' => $this->draw_reveal_after?->toIso8601String(),
                'revealed_at' => $this->drawn_at?->toIso8601String(),
                'seed' => $this->drawn_at !== null ? $this->draw_seed : null,
            ],
            'winners' => CagnotteWinnerResource::collection($this->whenLoaded('winners')),
            'contributions' => CagnotteContributionResource::collection($this->whenLoaded('contributions')),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    /** Les tickets du visiteur, même quand la liste des participations ne lui est pas montrée. */
    private function myTickets(?int $userId): ?int
    {
        if ($userId === null) {
            return null;
        }

        return $this->resource->relationLoaded('contributions')
            ? (int) $this->contributions->where('user_id', $userId)->sum('tickets')
            : (int) $this->resource->contributions()->where('user_id', $userId)->sum('tickets');
    }

    private function prizes(): array
    {
        $split = $this->prize_split ?? [];
        $amounts = CagnottePrizeDraw::prizeAmounts($this->resource->pot(), $split);

        $prizes = [];
        foreach (array_values($split) as $index => $percent) {
            $prizes[] = [
                'rank' => $index + 1,
                'percent' => $percent,
                'amount' => $amounts[$index] ?? 0,
            ];
        }

        return $prizes;
    }
}
