<?php

namespace App\Services\Fees;

use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use App\Models\FeeRule;

/**
 * Frais calculés pour une opération précise, avant qu'elle soit exécutée.
 *
 * Sert deux usages : l'écran de confirmation qui annonce le montant exact,
 * et le prélèvement lui-même, qui reprend les mêmes chiffres.
 */
final class FeeQuote
{
    public function __construct(
        public readonly FeeOperation $operation,
        public readonly int $base,
        public readonly int $fee,
        public readonly FeePayer $payer,
        public readonly int $rateBp = 0,
        public readonly int $fixedAmount = 0,
        public readonly ?FeeRule $rule = null,
    ) {}

    /** Ce que le payeur débourse réellement. */
    public function total(): int
    {
        return $this->payer->addsToAmount() ? $this->base + $this->fee : $this->base;
    }

    /** Ce qui arrive au bénéficiaire, ou ce qui est affecté à la tontine. */
    public function net(): int
    {
        return $this->payer->addsToAmount() ? $this->base : $this->base - $this->fee;
    }

    public function isFree(): bool
    {
        return $this->fee === 0;
    }

    /** Estimation de ce que l'opération coûte à la plateforme chez PayDunya. */
    public function providerCost(): int
    {
        return intdiv($this->total() * $this->operation->providerCostBp(), 10000);
    }

    public function platformMargin(): int
    {
        return $this->fee - $this->providerCost();
    }

    /** Phrase affichée avant la confirmation, sans jargon. */
    public function summary(): string
    {
        $amount = fn (int $value) => number_format($value, 0, ',', ' ').' FCFA';

        if ($this->isFree()) {
            return 'Aucun frais sur cette opération.';
        }

        return $this->payer->addsToAmount()
            ? "Vous payez {$amount($this->total())} : {$amount($this->base)} et {$amount($this->fee)} de frais de service."
            : "Sur {$amount($this->base)}, {$amount($this->fee)} de frais de service sont retenus : {$amount($this->net())} sont remis.";
    }

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'operation' => $this->operation->value,
            'label' => $this->operation->label(),
            'base_amount' => $this->base,
            'fee_amount' => $this->fee,
            'total_amount' => $this->total(),
            'net_amount' => $this->net(),
            'rate_bp' => $this->rateBp,
            'fixed_amount' => $this->fixedAmount,
            'payer' => $this->payer->value,
            'added_to_amount' => $this->payer->addsToAmount(),
            'summary' => $this->summary(),
        ];
    }
}
