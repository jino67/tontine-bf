<?php

namespace App\Http\Resources;

use App\Enums\PaymentStatus;
use App\Models\Contribution;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'purpose' => match ($this->payable_type) {
                (new Contribution)->getMorphClass() => 'cotisation',
                (new User)->getMorphClass() => 'depot',
                default => 'cagnotte',
            },
            'payable_id' => $this->payable_id,
            // amount est ce que le membre débourse : la base et les frais de service réunis.
            'amount' => $this->amount,
            'base_amount' => $this->base_amount,
            'fee_amount' => $this->fee_amount,
            'status' => $this->status->value,
            'checkout_url' => $this->status === PaymentStatus::Pending ? $this->checkout_url : null,
            'receipt_url' => $this->receipt_url,
            'failure_reason' => $this->failure_reason,
            // Faux si l'argent est reçu mais n'a pas pu être affecté : le trésorier doit le rapprocher.
            'applied' => $this->applied_at !== null,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
