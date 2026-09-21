<?php

namespace App\Enums;

/**
 * Opérations qui peuvent porter des frais de service.
 *
 * Les valeurs par défaut reprennent la grille publiée : elles sont insérées dans `fee_rules`
 * à la migration, et c'est cette table qui fait foi ensuite. Le code ne sert que de repli
 * si une règle venait à manquer.
 *
 * Le coût fournisseur est celui de PayDunya au Burkina Faso : 2,25 % à l'encaissement,
 * 2,00 % au reversement. La différence avec les frais facturés est la marge de la plateforme.
 */
enum FeeOperation: string
{
    case Deposit = 'depot_portefeuille';
    case Withdrawal = 'retrait_portefeuille';
    case Transfer = 'transfert_interne';
    case ContributionWallet = 'cotisation_solde';
    case ContributionOnline = 'cotisation_en_ligne';
    case ContributionCash = 'cotisation_especes';
    case CyclePayout = 'versement_tour';
    case PrizePool = 'cagnotte_gagnants';
    case SolidarityPool = 'cagnotte_solidaire';
    case MobileMoneyPayout = 'remise_mobile_money';

    public function label(): string
    {
        return match ($this) {
            self::Deposit => 'Dépôt sur le portefeuille',
            self::Withdrawal => 'Retrait vers mobile money',
            self::Transfer => 'Transfert entre membres',
            self::ContributionWallet => 'Cotisation payée depuis le solde',
            self::ContributionOnline => 'Cotisation payée en ligne',
            self::ContributionCash => 'Cotisation en espèces',
            self::CyclePayout => 'Versement d’un tour au bénéficiaire',
            self::PrizePool => 'Cagnotte à gagnants',
            self::SolidarityPool => 'Cagnotte solidaire',
            self::MobileMoneyPayout => 'Remise vers un compte mobile money',
        };
    }

    public function description(): string
    {
        return match ($this) {
            self::Deposit => 'Argent versé sur votre solde depuis votre compte mobile money.',
            self::Withdrawal => 'Argent sorti de votre solde vers votre compte mobile money.',
            self::Transfer => 'Envoi d’argent à un autre membre, de solde à solde. Gratuit.',
            self::ContributionWallet => 'Cotisation réglée avec l’argent déjà présent sur votre solde.',
            self::ContributionOnline => 'Cotisation réglée directement depuis votre compte mobile money.',
            self::ContributionCash => 'Cotisation remise de la main à la main et enregistrée par le trésorier. Gratuite.',
            self::CyclePayout => 'Somme du tour versée au membre dont c’est le rang.',
            self::PrizePool => 'Part retenue sur le pot avant le partage entre les gagnants.',
            self::SolidarityPool => 'Part retenue au moment de la remise des fonds au bénéficiaire.',
            self::MobileMoneyPayout => 'Envoi d’un gain ou d’un tour vers un compte mobile money.',
        };
    }

    /**
     * Repli si la règle n'existe pas en base.
     *
     * @return array{rate_bp: int, fixed_amount: int, min_amount: int, max_amount: int|null, payer: FeePayer}
     */
    public function defaults(): array
    {
        return match ($this) {
            self::Deposit => ['rate_bp' => 300, 'fixed_amount' => 0, 'min_amount' => 100, 'max_amount' => null, 'payer' => FeePayer::Payer],
            self::Withdrawal => ['rate_bp' => 250, 'fixed_amount' => 0, 'min_amount' => 100, 'max_amount' => null, 'payer' => FeePayer::Payer],
            self::Transfer => ['rate_bp' => 0, 'fixed_amount' => 0, 'min_amount' => 0, 'max_amount' => 0, 'payer' => FeePayer::Platform],
            self::ContributionWallet => ['rate_bp' => 100, 'fixed_amount' => 0, 'min_amount' => 0, 'max_amount' => 500, 'payer' => FeePayer::Payer],
            self::ContributionOnline => ['rate_bp' => 325, 'fixed_amount' => 0, 'min_amount' => 0, 'max_amount' => null, 'payer' => FeePayer::Payer],
            self::ContributionCash => ['rate_bp' => 0, 'fixed_amount' => 0, 'min_amount' => 0, 'max_amount' => 0, 'payer' => FeePayer::Platform],
            self::CyclePayout => ['rate_bp' => 100, 'fixed_amount' => 0, 'min_amount' => 0, 'max_amount' => 2000, 'payer' => FeePayer::Beneficiary],
            self::PrizePool => ['rate_bp' => 500, 'fixed_amount' => 0, 'min_amount' => 0, 'max_amount' => null, 'payer' => FeePayer::Beneficiary],
            self::SolidarityPool => ['rate_bp' => 200, 'fixed_amount' => 0, 'min_amount' => 0, 'max_amount' => null, 'payer' => FeePayer::Beneficiary],
            self::MobileMoneyPayout => ['rate_bp' => 250, 'fixed_amount' => 0, 'min_amount' => 100, 'max_amount' => null, 'payer' => FeePayer::Beneficiary],
        };
    }

    /** Ce que l'opération coûte réellement à la plateforme, en points de base. */
    public function providerCostBp(): int
    {
        return match ($this) {
            self::Deposit, self::ContributionOnline => 225,
            self::Withdrawal, self::MobileMoneyPayout => 200,
            self::PrizePool, self::SolidarityPool, self::CyclePayout => 225,
            self::Transfer, self::ContributionWallet, self::ContributionCash => 0,
        };
    }

    /** Frais retenus sur une somme reçue, au lieu d'être ajoutés au montant payé. */
    public function isDeducted(): bool
    {
        return ! $this->defaults()['payer']->addsToAmount();
    }

    /** @return array<int, self> ordre d'affichage de la page « Frais ». */
    public static function grid(): array
    {
        return [
            self::ContributionOnline,
            self::ContributionWallet,
            self::ContributionCash,
            self::CyclePayout,
            self::PrizePool,
            self::SolidarityPool,
            self::Deposit,
            self::Withdrawal,
            self::Transfer,
            self::MobileMoneyPayout,
        ];
    }
}
