<?php

namespace App\Http\Controllers\Api;

use App\Enums\CagnotteStatus;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Models\Cagnotte;
use App\Models\Organization;
use App\Services\CagnottePrizeDraw;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Tirage des gagnants d'une cagnotte clôturée : la liste des tickets et l'empreinte de la graine sont publiées,
 * puis n'importe quel membre révèle le résultat après la date annoncée.
 */
class CagnotteDrawController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function store(Request $request, Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        $this->ensureCanManage($request);

        $data = $request->validate([
            'reveal_after' => ['nullable', 'date', 'after_or_equal:now'],
        ]);

        DB::transaction(function () use ($cagnotte, $data) {
            $cagnotte = Cagnotte::whereKey($cagnotte->id)->lockForUpdate()->firstOrFail();

            if (! $cagnotte->isPrize()) {
                throw new DomainRuleException('Cette cagnotte n’a pas de gagnants à tirer.');
            }

            if ($cagnotte->draw_seed_hash !== null) {
                throw new DomainRuleException('Le tirage de cette cagnotte a déjà été lancé.');
            }

            if ($cagnotte->effectiveStatus() !== CagnotteStatus::Closed) {
                throw new DomainRuleException('Le tirage se lance une fois la cagnotte clôturée.');
            }

            $tickets = CagnottePrizeDraw::tickets($cagnotte->contributions()->get(['user_id', 'tickets']));

            if ($tickets === []) {
                throw new DomainRuleException('Aucun ticket n’a été vendu, il n’y a rien à tirer.');
            }

            $seed = bin2hex(random_bytes(32));

            $cagnotte->update([
                'status' => CagnotteStatus::Closed,
                'closed_at' => $cagnotte->closed_at ?? $cagnotte->ends_at,
                'draw_seed' => $seed,
                'draw_seed_hash' => hash('sha256', $seed),
                'draw_tickets' => $tickets,
                'draw_reveal_after' => isset($data['reveal_after']) ? Carbon::parse($data['reveal_after']) : now()->addHour(),
            ]);
        });

        return CagnotteResource::make($organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail());
    }

    /** Tout membre de l'organisation peut révéler le tirage une fois la date passée. */
    public function reveal(Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        DB::transaction(function () use ($cagnotte) {
            $cagnotte = Cagnotte::whereKey($cagnotte->id)->lockForUpdate()->firstOrFail();

            if ($cagnotte->draw_seed_hash === null) {
                throw new DomainRuleException('Le tirage de cette cagnotte n’a pas encore été lancé.');
            }

            if ($cagnotte->drawn_at !== null) {
                throw new DomainRuleException('Ce tirage a déjà été révélé.');
            }

            if (now()->lt($cagnotte->draw_reveal_after)) {
                $date = $cagnotte->draw_reveal_after->timezone('Africa/Ouagadougou')->format('d/m/Y à H:i');
                throw new DomainRuleException("Le tirage ne peut pas être révélé avant le {$date}.");
            }

            $winners = CagnottePrizeDraw::pickWinners(
                $cagnotte->draw_seed,
                $cagnotte->draw_tickets ?? [],
                $cagnotte->winners_count,
            );
            $amounts = CagnottePrizeDraw::awardedAmounts(
                CagnottePrizeDraw::pot($cagnotte->collectedAmount(), $cagnotte->fee_percent),
                $cagnotte->prize_split ?? [],
                array_column($winners, 'rank'),
            );

            foreach ($winners as $winner) {
                $cagnotte->winners()->create([
                    'organization_id' => $cagnotte->organization_id,
                    'rank' => $winner['rank'],
                    'user_id' => $winner['user_id'],
                    'prize_amount' => $amounts[$winner['rank']] ?? 0,
                ]);
            }

            $cagnotte->update(['status' => CagnotteStatus::Drawn, 'drawn_at' => now()]);
        });

        return CagnotteResource::make($organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail());
    }
}
