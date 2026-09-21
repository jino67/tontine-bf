<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletTransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reference' => $this->reference,
            'type' => $this->type->value,
            'label' => $this->type->label(),
            'status' => $this->status->value,
            'direction' => $this->direction->value,
            'amount' => $this->amount,
            'fee_amount' => $this->fee_amount,
            // Ce que l'opération change sur le solde : négatif quand l'argent sort.
            'signed_amount' => $this->resource->signedAmount(),
            'balance_after' => $this->balance_after,
            'counterparty' => $this->whenLoaded('counterparty', fn () => $this->counterparty?->name),
            'description' => $this->description,
            'failure_reason' => $this->failure_reason,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
