<?php

namespace App\Enums;

/** Qui peut voir une organisation, une tontine ou une cagnotte. */
enum Visibility: string
{
    /** Visible des seuls membres. Réglage par défaut de tout ce qui existe déjà. */
    case Members = 'privee';

    /** Accessible à qui possède le lien, absente de l'annuaire. */
    case Link = 'lien';

    /** Visible de tous et listée dans l'annuaire public. */
    case Listed = 'publique';

    /** Vrai dès qu'un lien de partage a du sens. */
    public function isShared(): bool
    {
        return $this !== self::Members;
    }

    public function isListed(): bool
    {
        return $this === self::Listed;
    }
}
