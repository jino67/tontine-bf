<?php

namespace App\Services\Fees;

use App\Enums\CagnotteMode;
use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use App\Models\Cagnotte;
use App\Models\FeeCharge;

/**
 * Part de la plateforme sur une cagnotte.
 *
 * Le taux est figé à la création : une cagnotte lancée sous un taux donné reste jugée
 * sous ce taux, et son pot reste recalculable à l'identique par l'application.
 * Le prélèvement, lui, n'est inscrit qu'au moment où l'argent sort : au tirage
 * pour une cagnotte à gagnants, à la remise des fonds pour une cagnotte solidaire.
 */
class CagnotteFees
{
    public function __construct(private FeeEngine $engine) {}

    public function operationFor(CagnotteMode $mode): FeeOperation
    {
        return $mode === CagnotteMode::Prize ? FeeOperation::PrizePool : FeeOperation::SolidarityPool;
    }

    /** Taux à figer dans la cagnotte au moment de sa création. */
    public function rateBpFor(CagnotteMode $mode, ?int $organizationId = null): int
    {
        return $this->engine->rateBp($this->operationFor($mode), $organizationId);
    }

    /** Inscrit le prélèvement, une seule fois par cagnotte. */
    public function chargePlatform(Cagnotte $cagnotte, string $note): ?FeeCharge
    {
        $operation = $this->operationFor($cagnotte->mode);
        $fee = $cagnotte->platformFee();

        if ($fee <= 0) {
            return null;
        }

        $existing = FeeCharge::query()
            ->where('chargeable_type', $cagnotte->getMorphClass())
            ->where('chargeable_id', $cagnotte->getKey())
            ->where('operation', $operation)
            ->first();

        if ($existing !== null) {
            return $existing;
        }

        return $this->engine->charge(
            new FeeQuote(
                operation: $operation,
                base: $cagnotte->onlineCollected(),
                fee: $fee,
                payer: FeePayer::Beneficiary,
                rateBp: (int) $cagnotte->platform_fee_bp,
            ),
            $cagnotte,
            $cagnotte->beneficiary_user_id,
            $cagnotte->organization_id,
            $note,
        );
    }
}
