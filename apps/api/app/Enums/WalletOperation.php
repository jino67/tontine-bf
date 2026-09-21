<?php

namespace App\Enums;

/** Ce qu'une ligne d'historique du portefeuille raconte au membre. */
enum WalletOperation: string
{
    case Deposit = 'depot';
    case Withdrawal = 'retrait';
    case Contribution = 'cotisation';
    case Participation = 'participation';
    case Prize = 'gain';
    case CyclePayout = 'tour';
    case Handover = 'remise';
    case TransferOut = 'transfert_envoye';
    case TransferIn = 'transfert_recu';
    case Refund = 'remboursement';

    public function label(): string
    {
        return match ($this) {
            self::Deposit => 'Dépôt',
            self::Withdrawal => 'Retrait',
            self::Contribution => 'Cotisation',
            self::Participation => 'Participation à une cagnotte',
            self::Prize => 'Gain reçu',
            self::CyclePayout => 'Tour reçu',
            self::Handover => 'Fonds d’une cagnotte reçus',
            self::TransferOut => 'Envoi à un membre',
            self::TransferIn => 'Reçu d’un membre',
            self::Refund => 'Remboursement',
        };
    }

    /** Sens du mouvement pour le membre : ce qui entre sur son solde est un crédit. */
    public function direction(): LedgerDirection
    {
        return match ($this) {
            self::Deposit, self::Prize, self::CyclePayout, self::Handover, self::TransferIn, self::Refund => LedgerDirection::Credit,
            self::Withdrawal, self::Contribution, self::Participation, self::TransferOut => LedgerDirection::Debit,
        };
    }
}
