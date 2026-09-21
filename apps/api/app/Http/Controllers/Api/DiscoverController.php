<?php

namespace App\Http\Controllers\Api;

use App\Enums\CagnotteStatus;
use App\Enums\TontineType;
use App\Enums\Visibility;
use App\Http\Controllers\Controller;
use App\Models\Cagnotte;
use App\Models\Tontine;
use App\Services\ShareLinks;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Annuaire public : tontines ouvertes aux demandes et cagnottes visibles de tous.
 *
 * Les fiches passent par ShareLinks, qui garantit l'absence de donnée personnelle.
 */
class DiscoverController extends Controller
{
    private const LIMIT = 30;

    public function __invoke(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:80'],
            'type' => ['nullable', Rule::enum(TontineType::class)],
            'max_amount' => ['nullable', 'integer', 'min:100'],
        ]);

        return response()->json([
            'data' => [
                'tontines' => $this->tontines($filters),
                'cagnottes' => $this->cagnottes($filters),
            ],
        ]);
    }

    /** @param  array<string, mixed>  $filters */
    private function tontines(array $filters): array
    {
        $tontines = Tontine::query()
            ->with(['organization', 'creator'])
            ->withCount('members')
            ->where('visibility', Visibility::Listed)
            ->whereNull('hidden_at')
            ->whereNull('started_at')
            ->when($filters['q'] ?? null, fn ($query, $q) => $query->where('name', 'like', '%'.$q.'%'))
            ->when($filters['type'] ?? null, fn ($query, $type) => $query->where('type', $type))
            ->when($filters['max_amount'] ?? null, fn ($query, $amount) => $query->where('amount', '<=', $amount))
            ->orderBy('starts_on')
            ->limit(self::LIMIT)
            ->get();

        return $tontines->map(fn (Tontine $tontine) => ShareLinks::tontine($tontine))->all();
    }

    /** @param  array<string, mixed>  $filters */
    private function cagnottes(array $filters): array
    {
        $cagnottes = Cagnotte::query()
            ->with('organization')
            ->withCount('contributions')
            ->where('visibility', Visibility::Listed)
            ->whereNull('hidden_at')
            ->where('status', CagnotteStatus::Open)
            ->where('ends_at', '>', now())
            ->when($filters['q'] ?? null, fn ($query, $q) => $query->where('title', 'like', '%'.$q.'%'))
            ->orderBy('ends_at')
            ->limit(self::LIMIT)
            ->get();

        return $cagnottes->map(fn (Cagnotte $cagnotte) => ShareLinks::cagnotte($cagnotte))->all();
    }
}
