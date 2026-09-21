<?php

namespace App\Http\Controllers\Admin;

use App\Enums\CagnotteDuration;
use App\Enums\CagnotteMode;
use App\Enums\Visibility;
use App\Http\Controllers\Controller;
use App\Models\CagnotteTemplate;
use App\Services\CagnottePrizeDraw;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * Modèles de cagnotte.
 *
 * C'est ici que se décident les formules proposées dans l'application : prix du ticket,
 * nombre de gagnants, répartition, récurrence. Un modèle ne contraint personne — il remplit
 * les champs laissés vides à la création, et tout reste modifiable ensuite.
 */
class TemplateController extends Controller
{
    public function index(): View
    {
        return view('admin.templates', [
            'templates' => CagnotteTemplate::orderBy('sort_order')->orderBy('name')->get(),
            'modes' => CagnotteMode::cases(),
            'durations' => CagnotteDuration::cases(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $template = CagnotteTemplate::create($this->validated($request) + ['created_by' => $request->user()->id]);

        return redirect()->route('admin.templates.index')->with('status', "Modèle « {$template->name} » créé.");
    }

    public function update(Request $request, CagnotteTemplate $template): RedirectResponse
    {
        $template->update($this->validated($request));

        return redirect()->route('admin.templates.index')->with('status', "Modèle « {$template->name} » enregistré.");
    }

    /** Un modèle déjà utilisé n'est pas supprimé mais retiré de la liste : l'historique reste lisible. */
    public function destroy(CagnotteTemplate $template): RedirectResponse
    {
        if ($template->cagnottes()->exists()) {
            $template->update(['active' => false]);

            return redirect()->route('admin.templates.index')->with('status', 'Modèle retiré de la liste, ses cagnottes sont conservées.');
        }

        $template->delete();

        return redirect()->route('admin.templates.index')->with('status', 'Modèle supprimé.');
    }

    /** @return array<string, mixed> */
    private function validated(Request $request): array
    {
        $prize = $request->input('mode') === CagnotteMode::Prize->value;

        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:1000'],
            'mode' => ['required', Rule::enum(CagnotteMode::class)],
            'duration' => ['required', Rule::enum(CagnotteDuration::class)],
            'ticket_price' => [Rule::requiredIf($prize), 'nullable', 'integer', 'min:50', 'max:1000000'],
            'winners_count' => [Rule::requiredIf($prize), 'nullable', 'integer', 'min:1', 'max:10'],
            'prize_split' => ['nullable', 'string', 'max:120'],
            'min_amount' => ['nullable', 'integer', 'min:50', 'max:10000000'],
            'target_amount' => ['nullable', 'integer', 'min:100', 'max:100000000'],
            'fee_percent' => ['nullable', 'integer', 'min:0', 'max:30'],
            'recurring' => ['nullable', 'boolean'],
            'visibility' => ['required', Rule::enum(Visibility::class)],
            'active' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer', 'min:0', 'max:999'],
        ]);

        $data['recurring'] = $request->boolean('recurring');
        $data['active'] = $request->boolean('active');
        $data['prize_split'] = $prize ? $this->split($data) : null;

        return $data;
    }

    /** « 50/30/20 » devient [50, 30, 20]. Vide, la répartition par défaut du nombre de gagnants s'applique. */
    private function split(array $data): array
    {
        $winners = (int) $data['winners_count'];
        $raw = trim((string) ($data['prize_split'] ?? ''));

        if ($raw === '') {
            return CagnottePrizeDraw::defaultSplit($winners);
        }

        $split = array_map('floatval', preg_split('/[\s\/,;]+/', $raw, -1, PREG_SPLIT_NO_EMPTY) ?: []);

        if (! CagnottePrizeDraw::isValidSplit($split, $winners)) {
            throw ValidationException::withMessages([
                'prize_split' => 'La répartition doit prévoir une part par gagnant et totaliser 100 %.',
            ]);
        }

        return $split;
    }
}
