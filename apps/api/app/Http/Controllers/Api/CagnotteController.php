<?php

namespace App\Http\Controllers\Api;

use App\Enums\CagnotteDuration;
use App\Enums\CagnotteMode;
use App\Enums\CagnotteStatus;
use App\Enums\Visibility;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Models\Cagnotte;
use App\Models\CagnotteTemplate;
use App\Models\Organization;
use App\Services\CagnottePrizeDraw;
use App\Services\Fees\CagnotteFees;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CagnotteController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function __construct(private CagnotteFees $fees) {}

    /** Toutes les cagnottes de l'organisation sont visibles par tous ses membres. */
    public function index(Organization $organization): AnonymousResourceCollection
    {
        return CagnotteResource::collection(
            $organization->cagnottes()->with('beneficiary')->withTotals()->latest('id')->get()
        );
    }

    public function store(Request $request, Organization $organization): JsonResponse
    {
        $this->ensureCanManage($request);

        $this->applyTemplate($request);

        $duration = is_string($request->input('duration')) ? CagnotteDuration::tryFrom($request->input('duration')) : null;
        $mode = is_string($request->input('mode')) ? CagnotteMode::tryFrom($request->input('mode')) : CagnotteMode::Solidarity;
        $prize = $mode === CagnotteMode::Prize;
        $member = Rule::exists('organization_user', 'user_id')->where('organization_id', $organization->id);

        $data = $request->validate([
            'mode' => ['nullable', Rule::enum(CagnotteMode::class)],
            'title' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:1000'],
            'duration' => ['required', Rule::enum(CagnotteDuration::class)],
            'ends_at' => [Rule::requiredIf($duration === CagnotteDuration::Custom), 'nullable', 'date', 'after:now', 'before:+366 days'],
            'target_amount' => ['nullable', 'integer', 'min:100', 'max:100000000'],
            'min_amount' => ['nullable', 'integer', 'min:100', 'max:10000000'],
            'beneficiary_user_id' => ['nullable', 'integer', $member],
            'beneficiary_name' => ['nullable', 'string', 'max:120', ...($prize ? [] : ['required_without:beneficiary_user_id'])],
            'ticket_price' => [Rule::requiredIf($prize), 'nullable', 'integer', 'min:50', 'max:1000000'],
            'winners_count' => [Rule::requiredIf($prize), 'nullable', 'integer', 'min:1', 'max:10'],
            'prize_split' => ['nullable', 'array'],
            'prize_split.*' => ['numeric', 'gt:0'],
            'fee_percent' => ['nullable', 'integer', 'min:0', 'max:30'],
            'visibility' => ['nullable', Rule::enum(Visibility::class)],
            // Une cagnotte récurrente repart pour une nouvelle édition dès que le tirage est révélé.
            'recurring' => ['nullable', 'boolean'],
            'template_id' => ['nullable', 'integer', Rule::exists('cagnotte_templates', 'id')->where('active', true)],
        ]);

        $prizeFields = $prize ? $this->prizeFields($data) : [];
        $memberBeneficiary = $prize ? null : ($data['beneficiary_user_id'] ?? null);
        $opensAt = now();

        $cagnotte = $organization->cagnottes()->create([
            'created_by' => $request->user()->id,
            'mode' => $mode,
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'duration' => $duration,
            'target_amount' => $data['target_amount'] ?? null,
            'min_amount' => $prize ? $prizeFields['ticket_price'] : ($data['min_amount'] ?? 100),
            'beneficiary_user_id' => $memberBeneficiary,
            'beneficiary_name' => $prize || $memberBeneficiary !== null ? null : $data['beneficiary_name'],
            'opens_at' => $opensAt,
            'ends_at' => $duration->endsAt($opensAt) ?? Carbon::parse($data['ends_at']),
            'platform_fee_bp' => $this->fees->rateBpFor($mode, $organization->id),
            'visibility' => $data['visibility'] ?? Visibility::Listed,
            'recurring' => (bool) ($data['recurring'] ?? false),
            'template_id' => $data['template_id'] ?? null,
            ...$prizeFields,
        ]);

        return CagnotteResource::make($this->detail($organization, $cagnotte))->response()->setStatusCode(201);
    }

    public function show(Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        return CagnotteResource::make($this->detail($organization, $cagnotte));
    }

    /** Clôture avant la date prévue, décidée par un responsable. */
    public function close(Request $request, Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        $this->ensureCanManage($request);

        if ($cagnotte->status !== CagnotteStatus::Open) {
            throw new DomainRuleException('Cette cagnotte est déjà clôturée.');
        }

        $cagnotte->update(['status' => CagnotteStatus::Closed, 'closed_at' => now()]);

        return CagnotteResource::make($this->detail($organization, $cagnotte));
    }

    /** Un modèle ne fait que remplir les champs laissés vides : ce qui est saisi l'emporte. */
    private function applyTemplate(Request $request): void
    {
        $template = CagnotteTemplate::query()
            ->usable()
            ->whereKey($request->integer('template_id'))
            ->first();

        if ($template === null) {
            return;
        }

        foreach ($template->attributesForCagnotte() as $field => $value) {
            if (! $request->filled($field)) {
                $request->merge([$field => $value instanceof \BackedEnum ? $value->value : $value]);
            }
        }
    }

    private function prizeFields(array $data): array
    {
        $winners = (int) $data['winners_count'];
        $split = isset($data['prize_split'])
            ? array_map('floatval', array_values($data['prize_split']))
            : CagnottePrizeDraw::defaultSplit($winners);

        if (! CagnottePrizeDraw::isValidSplit($split, $winners)) {
            throw ValidationException::withMessages([
                'prize_split' => 'La répartition doit prévoir une part par gagnant et totaliser 100 %.',
            ]);
        }

        return [
            'ticket_price' => (int) $data['ticket_price'],
            'winners_count' => $winners,
            'prize_split' => $split,
            'fee_percent' => (int) ($data['fee_percent'] ?? 0),
        ];
    }

    private function detail(Organization $organization, Cagnotte $cagnotte): Cagnotte
    {
        return $organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail();
    }
}
