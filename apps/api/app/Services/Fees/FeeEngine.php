<?php

namespace App\Services\Fees;

use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use App\Models\FeeCharge;
use App\Models\FeeRule;
use Illuminate\Database\Eloquent\Model;

/**
 * Calcul et prélèvement des frais de service.
 *
 * Deux principes tenus partout :
 * — aucun taux écrit en dur : tout vient de `fee_rules`, le code ne sert que de repli ;
 * — les frais ne portent que sur l'argent qui passe réellement par la plateforme.
 *   Une cotisation remise en espèces au trésorier ne coûte rien, et c'est voulu.
 */
class FeeEngine
{
    /** Le franc CFA ne circule plus en dessous de 5 : tout montant facturé est un multiple de 5. */
    private const ROUNDING = 5;

    /** @var array<string, FeeRule|null> règles déjà lues pendant la requête */
    private array $rules = [];

    public function quote(FeeOperation $operation, int $base, ?int $organizationId = null): FeeQuote
    {
        $base = max(0, $base);
        $rule = $this->rule($operation, $organizationId);
        $settings = $rule === null ? $operation->defaults() : [
            'rate_bp' => $rule->rate_bp,
            'fixed_amount' => $rule->fixed_amount,
            'min_amount' => $rule->min_amount,
            'max_amount' => $rule->max_amount,
            'payer' => $rule->payer,
        ];

        return new FeeQuote(
            operation: $operation,
            base: $base,
            fee: $this->amount($base, $settings),
            payer: $settings['payer'],
            rateBp: $settings['rate_bp'],
            fixedAmount: $settings['fixed_amount'],
            rule: $rule,
        );
    }

    /** Taux en vigueur, à figer dans un objet dont le calcul doit rester reproductible. */
    public function rateBp(FeeOperation $operation, ?int $organizationId = null): int
    {
        return $this->rule($operation, $organizationId)?->rate_bp ?? $operation->defaults()['rate_bp'];
    }

    /** Enregistre le prélèvement. Rien n'est écrit quand l'opération est gratuite. */
    public function charge(
        FeeQuote $quote,
        ?Model $chargeable = null,
        ?int $userId = null,
        ?int $organizationId = null,
        ?string $note = null,
    ): ?FeeCharge {
        if ($quote->isFree()) {
            return null;
        }

        return FeeCharge::create([
            'organization_id' => $organizationId,
            'user_id' => $userId,
            'fee_rule_id' => $quote->rule?->id,
            'operation' => $quote->operation,
            'chargeable_type' => $chargeable?->getMorphClass(),
            'chargeable_id' => $chargeable?->getKey(),
            'base_amount' => $quote->base,
            'fee_amount' => $quote->fee,
            'rate_bp' => $quote->rateBp,
            'fixed_amount' => $quote->fixedAmount,
            'payer' => $quote->payer,
            'provider_cost' => $quote->providerCost(),
            'platform_margin' => $quote->platformMargin(),
            'note' => $note,
        ]);
    }

    /**
     * Grille complète, telle qu'elle est affichée dans l'application et sur la page publique.
     *
     * @return array<int, array<string, mixed>>
     */
    public function grid(?int $organizationId = null): array
    {
        return array_map(function (FeeOperation $operation) use ($organizationId) {
            $rule = $this->rule($operation, $organizationId);
            $defaults = $operation->defaults();

            return [
                'operation' => $operation->value,
                'label' => $operation->label(),
                'description' => $operation->description(),
                'rate_bp' => $rule?->rate_bp ?? $defaults['rate_bp'],
                'fixed_amount' => $rule?->fixed_amount ?? $defaults['fixed_amount'],
                'min_amount' => $rule?->min_amount ?? $defaults['min_amount'],
                'max_amount' => $rule === null ? $defaults['max_amount'] : $rule->max_amount,
                'payer' => ($rule?->payer ?? $defaults['payer'])->value,
                'payer_label' => ($rule?->payer ?? $defaults['payer'])->label(),
                'deducted' => ! ($rule?->payer ?? $defaults['payer'])->addsToAmount(),
                'rate_label' => $rule?->rateLabel() ?? $this->defaultRateLabel($defaults),
            ];
        }, FeeOperation::grid());
    }

    /** @param  array{rate_bp: int, fixed_amount: int, min_amount: int, max_amount: int|null, payer: FeePayer}  $settings */
    private function amount(int $base, array $settings): int
    {
        $raw = intdiv($base * $settings['rate_bp'], 10000) + $settings['fixed_amount'];
        $fee = $this->roundUp($raw);

        if ($fee > 0 && $settings['min_amount'] > 0) {
            $fee = max($fee, $settings['min_amount']);
        }

        if ($settings['max_amount'] !== null) {
            $fee = min($fee, $settings['max_amount']);
        }

        // Des frais retenus ne peuvent pas dépasser la somme sur laquelle ils sont pris.
        return $settings['payer']->addsToAmount() ? $fee : min($fee, $base);
    }

    private function roundUp(int $amount): int
    {
        return intdiv($amount + self::ROUNDING - 1, self::ROUNDING) * self::ROUNDING;
    }

    private function rule(FeeOperation $operation, ?int $organizationId): ?FeeRule
    {
        $key = $operation->value.':'.($organizationId ?? 0);

        return $this->rules[$key] ??= FeeRule::query()->inForce($operation, $organizationId)->first();
    }

    /** @param  array{rate_bp: int, fixed_amount: int, min_amount: int, max_amount: int|null, payer: FeePayer}  $defaults */
    private function defaultRateLabel(array $defaults): string
    {
        return (new FeeRule($defaults))->rateLabel();
    }
}
