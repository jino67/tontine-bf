<?php

namespace App\Enums;

/** Sens d'une écriture. Les deux sens d'une même transaction s'équilibrent toujours au franc près. */
enum LedgerDirection: string
{
    case Debit = 'debit';

    case Credit = 'credit';

    public function opposite(): self
    {
        return $this === self::Debit ? self::Credit : self::Debit;
    }
}
