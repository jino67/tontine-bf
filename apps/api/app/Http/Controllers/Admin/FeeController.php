<?php

namespace App\Http\Controllers\Admin;

use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use App\Http\Controllers\Controller;
use App\Models\FeeCharge;
use App\Models\FeeRule;
use App\Models\Organization;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

/**
 * Grille des frais.
 *
 * Une règle ne se modifie jamais : on la clôt, et on en crée une nouvelle. Les opérations
 * déjà facturées gardent ainsi la règle qui leur a été appliquée, et un montant d'il y a six
 * mois reste explicable.
 */
class FeeController extends Controller
{
    public function index(): View
    {
        return view('admin.fees', [
            'rules' => FeeRule::with('organization')->orderBy('operation')->orderByDesc('id')->get()->groupBy('operation.value'),
            'operations' => FeeOperation::grid(),
            'payers' => FeePayer::cases(),
            'organizations' => Organization::where('kind', 'standard')->orderBy('name')->limit(200)->get(),
            'revenue' => $this->revenue(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'operation' => ['required', Rule::enum(FeeOperation::class)],
            'organization_id' => ['nullable', 'integer', 'exists:organizations,id'],
            'label' => ['nullable', 'string', 'max:120'],
            'rate_bp' => ['required', 'integer', 'min:0', 'max:5000'],
            'fixed_amount' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'min_amount' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'max_amount' => ['nullable', 'integer', 'min:0', 'max:10000000'],
            'payer' => ['required', Rule::enum(FeePayer::class)],
        ]);

        DB::transaction(function () use ($data, $request) {
            // La règle en place est close à l'instant où la nouvelle entre en vigueur.
            FeeRule::query()
                ->where('operation', $data['operation'])
                ->where('organization_id', $data['organization_id'] ?? null)
                ->where('active', true)
                ->whereNull('ends_at')
                ->update(['ends_at' => now(), 'active' => false]);

            FeeRule::create([
                ...$data,
                'starts_at' => now(),
                'active' => true,
                'created_by' => $request->user()->id,
            ]);
        });

        return redirect()->route('admin.fees.index')->with('status', 'Nouvelle règle en vigueur.');
    }

    public function destroy(Request $request, FeeRule $rule): RedirectResponse
    {
        $rule->update(['ends_at' => now(), 'active' => false]);

        return redirect()->route('admin.fees.index')->with('status', 'Règle close. Le tarif général reprend la main.');
    }

    /**
     * Ce que les frais ont rapporté par opération, sur trente jours.
     *
     * @return array<int, object>
     */
    private function revenue(): array
    {
        return FeeCharge::query()
            ->selectRaw('operation, count(*) as operations, sum(fee_amount) as fees, sum(platform_margin) as margin')
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('operation')
            ->orderByDesc('fees')
            ->get()
            ->all();
    }
}
