<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Report;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

/**
 * File des signalements.
 *
 * Trois signalements distincts masquent déjà une fiche automatiquement : le back-office sert
 * à confirmer ce masquage, ou à le lever quand il est abusif. Masquer ne supprime rien et ne
 * bloque pas les membres déjà entrés : leur argent et leur historique restent intacts.
 */
class ModerationController extends Controller
{
    public function index(Request $request): View
    {
        $treated = $request->query('etat') === 'traites';

        $reports = Report::query()
            ->with(['user', 'reportable'])
            ->when($treated, fn ($query) => $query->whereNotNull('reviewed_at'))
            ->when(! $treated, fn ($query) => $query->whereNull('reviewed_at'))
            ->latest('id')
            ->limit(200)
            ->get();

        return view('admin.moderation', [
            'groups' => $this->grouped($reports),
            'treated' => $treated,
            'pendingCount' => Report::whereNull('reviewed_at')->count(),
        ]);
    }

    public function update(Request $request, Report $report): RedirectResponse
    {
        $data = $request->validate([
            'decision' => ['required', Rule::in(['masquee', 'conservee'])],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $target = $report->reportable;
        $hidden = $data['decision'] === 'masquee';

        if ($target !== null) {
            $target->forceFill(['hidden_at' => $hidden ? now() : null])->save();

            // Une décision vaut pour toute la fiche, pas pour le seul signalement ouvert.
            Report::where('reportable_type', $report->reportable_type)
                ->where('reportable_id', $report->reportable_id)
                ->whereNull('reviewed_at')
                ->update([
                    'reviewed_at' => now(),
                    'reviewed_by' => $request->user()->id,
                    'decision' => $data['decision'],
                    'review_note' => $data['note'] ?? null,
                ]);
        }

        return back()->with('status', $hidden ? 'Fiche masquée.' : 'Fiche rétablie et signalements clos.');
    }

    /**
     * Un objet signalé plusieurs fois n'apparaît qu'une fois, avec tous ses motifs.
     *
     * @param  Collection<int, Report>  $reports
     * @return Collection<string, array<string, mixed>>
     */
    private function grouped(Collection $reports): Collection
    {
        return $reports
            ->groupBy(fn (Report $report) => $report->reportable_type.':'.$report->reportable_id)
            ->map(fn (Collection $group) => [
                'target' => $group->first()->reportable,
                'kind' => class_basename($group->first()->reportable_type),
                'reports' => $group,
                'count' => $group->count(),
                'hidden' => $group->first()->reportable?->hidden_at !== null,
            ]);
    }
}
