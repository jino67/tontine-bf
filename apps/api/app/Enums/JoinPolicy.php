<?php

namespace App\Enums;

/** Comment on entre dans une organisation ou dans une tontine. */
enum JoinPolicy: string
{
    /** Uniquement sur invitation nominative. */
    case Closed = 'fermee';

    /** Chacun peut demander, un responsable approuve ou refuse. */
    case OnRequest = 'sur_demande';

    /** L'adhésion est immédiate, sans approbation. */
    case Open = 'libre';

    public function acceptsRequests(): bool
    {
        return $this !== self::Closed;
    }
}
