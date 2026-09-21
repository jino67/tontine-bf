<?php

namespace App\Http\Controllers\Api;

use App\Enums\ReportReason;
use App\Enums\Visibility;
use App\Http\Controllers\Controller;
use App\Models\Cagnotte;
use App\Models\Report;
use App\Models\Tontine;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Signalement d'une fiche publique. Trois signalements distincts la retirent de l'annuaire. */
class ReportController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:tontine,cagnotte'],
            'id' => ['required', 'integer'],
            'reason' => ['required', Rule::enum(ReportReason::class)],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $target = $this->target($data['type'], (int) $data['id']);

        Report::firstOrCreate(
            ['reportable_type' => $target->getMorphClass(), 'reportable_id' => $target->getKey(), 'user_id' => $request->user()->id],
            ['reason' => $data['reason'], 'note' => $data['note'] ?? null],
        );

        $count = Report::where('reportable_type', $target->getMorphClass())
            ->where('reportable_id', $target->getKey())
            ->count();

        if ($count >= Report::THRESHOLD && $target->hidden_at === null) {
            $target->forceFill(['hidden_at' => now()])->save();
        }

        return response()->json([
            'message' => 'Signalement enregistré. Merci : il sera examiné.',
            'hidden' => $target->hidden_at !== null,
        ], 201);
    }

    private function target(string $type, int $id): Model
    {
        $shared = [Visibility::Link->value, Visibility::Listed->value];

        return $type === 'tontine'
            ? Tontine::whereKey($id)->whereIn('visibility', $shared)->firstOrFail()
            : Cagnotte::whereKey($id)->whereIn('visibility', $shared)->firstOrFail();
    }
}
