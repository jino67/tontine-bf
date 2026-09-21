@extends('admin.layout')

@section('title', 'Frais de service')

@section('content')
    <h2>Frais de service</h2>
    <p class="sous">
        Une règle ne se modifie pas : elle se clôt, et une nouvelle prend sa suite. Les opérations
        déjà facturées gardent la règle qui leur a été appliquée, et un montant d’il y a six mois
        reste explicable.
    </p>

    <h3>Ce que les frais ont rapporté, sur trente jours</h3>
    @if($revenue === [])
        <p class="aide">Aucun frais prélevé sur la période.</p>
    @else
        <table>
            <thead>
            <tr><th>Opération</th><th class="nombre">Opérations</th><th class="nombre">Frais perçus</th><th class="nombre">Marge estimée</th></tr>
            </thead>
            <tbody>
            @foreach($revenue as $line)
                <tr>
                    <td>{{ \App\Enums\FeeOperation::from($line->operation)->label() }}</td>
                    <td class="nombre">{{ number_format($line->operations, 0, ',', ' ') }}</td>
                    <td class="nombre">@fcfa($line->fees)</td>
                    <td class="nombre">@fcfa($line->margin)</td>
                </tr>
            @endforeach
            </tbody>
        </table>
        <p class="aide">
            La marge est l’écart entre ce qui est facturé et ce que l’opération coûte chez PayDunya
            (2,25 % à l’encaissement, 2,00 % au reversement). C’est une estimation, pas un relevé.
        </p>
    @endif

    <h3>Nouvelle règle</h3>
    <form class="bloc" method="post" action="{{ route('admin.fees.store') }}">
        @csrf
        <div class="champs">
            <div style="grid-column: span 2;">
                <label for="operation">Opération</label>
                <select id="operation" name="operation">
                    @foreach($operations as $operation)
                        <option value="{{ $operation->value }}">{{ $operation->label() }}</option>
                    @endforeach
                </select>
            </div>
            <div style="grid-column: span 2;">
                <label for="organization_id">Portée</label>
                <select id="organization_id" name="organization_id">
                    <option value="">Toutes les organisations</option>
                    @foreach($organizations as $organization)
                        <option value="{{ $organization->id }}">{{ $organization->name }}</option>
                    @endforeach
                </select>
            </div>
            <div>
                <label for="rate_bp">Taux (points de base)</label>
                <input id="rate_bp" name="rate_bp" type="number" min="0" max="5000" value="{{ old('rate_bp', 0) }}" required>
                <div class="aide">325 valent 3,25 %.</div>
            </div>
            <div>
                <label for="fixed_amount">Part fixe</label>
                <input id="fixed_amount" name="fixed_amount" type="number" min="0" value="{{ old('fixed_amount', 0) }}">
            </div>
            <div>
                <label for="min_amount">Minimum facturé</label>
                <input id="min_amount" name="min_amount" type="number" min="0" value="{{ old('min_amount', 0) }}">
            </div>
            <div>
                <label for="max_amount">Plafond (vide = aucun)</label>
                <input id="max_amount" name="max_amount" type="number" min="0" value="{{ old('max_amount') }}">
            </div>
            <div>
                <label for="payer">Qui paie</label>
                <select id="payer" name="payer">
                    @foreach($payers as $payer)
                        <option value="{{ $payer->value }}">{{ $payer->label() }}</option>
                    @endforeach
                </select>
            </div>
            <div style="grid-column: span 2;">
                <label for="label">Intitulé (facultatif)</label>
                <input id="label" name="label" maxlength="120" value="{{ old('label') }}" placeholder="Tarif du plan payant">
            </div>
        </div>
        <p style="margin: 16px 0 0;"><button type="submit">Mettre en vigueur</button></p>
        <p class="aide">
            Les frais sont arrondis au multiple de 5 FCFA supérieur, et ne portent que sur l’argent
            qui passe réellement par l’application. Le plancher à ne pas franchir est 4,25 % sur un
            aller-retour complet : en dessous, chaque opération coûte de l’argent à la plateforme.
        </p>
    </form>

    <h3>Règles en vigueur</h3>
    @foreach($rules as $operation => $group)
        <h3 style="font-size: 15px; margin-bottom: 6px;">{{ \App\Enums\FeeOperation::from($operation)->label() }}</h3>
        <table>
            <thead>
            <tr>
                <th>Portée</th><th class="nombre">Taux</th><th class="nombre">Fixe</th><th class="nombre">Min.</th>
                <th class="nombre">Plafond</th><th>Qui paie</th><th>Période</th><th></th>
            </tr>
            </thead>
            <tbody>
            @foreach($group as $rule)
                <tr>
                    <td>{{ $rule->organization?->name ?? 'Toutes' }} @if($rule->label)<div class="aide">{{ $rule->label }}</div>@endif</td>
                    <td class="nombre">{{ $rule->rateLabel() }}</td>
                    <td class="nombre">{{ $rule->fixed_amount ?: '—' }}</td>
                    <td class="nombre">{{ $rule->min_amount ?: '—' }}</td>
                    <td class="nombre">{{ $rule->max_amount === null ? 'aucun' : number_format($rule->max_amount, 0, ',', ' ') }}</td>
                    <td>{{ $rule->payer->label() }}</td>
                    <td>
                        {{ $rule->starts_at?->format('d/m/Y') ?? '—' }}
                        @if($rule->ends_at)→ {{ $rule->ends_at->format('d/m/Y') }}@endif
                        @if($rule->active)<span class="etiquette vert">en vigueur</span>@else<span class="etiquette gris">close</span>@endif
                    </td>
                    <td>
                        @if($rule->active)
                            <form method="post" action="{{ route('admin.fees.destroy', $rule) }}"
                                  onsubmit="return confirm('Clore cette règle ?');">
                                @csrf
                                @method('delete')
                                <button class="discret" type="submit">Clore</button>
                            </form>
                        @endif
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endforeach
@endsection
