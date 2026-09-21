@extends('admin.layout')

@section('title', 'Modèles de cagnotte')

@section('content')
    <h2>Modèles de cagnotte</h2>
    <p class="sous">
        Les formules proposées à la création d’une cagnotte dans l’application. Un modèle ne
        contraint personne : il remplit les champs laissés vides, et tout reste modifiable ensuite.
    </p>

    <h3>Nouveau modèle</h3>
    <form class="bloc" method="post" action="{{ route('admin.templates.store') }}">
        @csrf
        <div class="champs">
            <div style="grid-column: span 2;">
                <label for="name">Nom</label>
                <input id="name" name="name" maxlength="120" value="{{ old('name') }}" required
                       placeholder="Tombola du vendredi">
            </div>
            <div>
                <label for="mode">Type</label>
                <select id="mode" name="mode">
                    @foreach($modes as $mode)
                        <option value="{{ $mode->value }}" @selected(old('mode', 'gagnants') === $mode->value)>
                            {{ $mode->value === 'gagnants' ? 'À gagnants (tirage)' : 'Solidaire (remise)' }}
                        </option>
                    @endforeach
                </select>
            </div>
            <div>
                <label for="duration">Durée</label>
                <select id="duration" name="duration">
                    @foreach($durations as $duration)
                        <option value="{{ $duration->value }}" @selected(old('duration', 'hebdo_7j') === $duration->value)>
                            {{ str_replace('_', ' ', $duration->value) }}
                        </option>
                    @endforeach
                </select>
            </div>
            <div>
                <label for="ticket_price">Prix du ticket</label>
                <input id="ticket_price" name="ticket_price" type="number" min="50" value="{{ old('ticket_price') }}">
            </div>
            <div>
                <label for="winners_count">Nombre de gagnants</label>
                <input id="winners_count" name="winners_count" type="number" min="1" max="10" value="{{ old('winners_count') }}">
            </div>
            <div>
                <label for="prize_split">Répartition</label>
                <input id="prize_split" name="prize_split" value="{{ old('prize_split') }}" placeholder="50/30/20">
            </div>
            <div>
                <label for="fee_percent">Commission de l’organisation (%)</label>
                <input id="fee_percent" name="fee_percent" type="number" min="0" max="30" value="{{ old('fee_percent', 0) }}">
            </div>
            <div>
                <label for="min_amount">Participation minimale</label>
                <input id="min_amount" name="min_amount" type="number" min="50" value="{{ old('min_amount', 100) }}">
            </div>
            <div>
                <label for="target_amount">Objectif (facultatif)</label>
                <input id="target_amount" name="target_amount" type="number" min="100" value="{{ old('target_amount') }}">
            </div>
            <div>
                <label for="visibility">Visibilité</label>
                <select id="visibility" name="visibility">
                    <option value="publique">Visible de tous</option>
                    <option value="lien">Par lien seulement</option>
                    <option value="privee">Privée</option>
                </select>
            </div>
            <div>
                <label for="sort_order">Ordre d’affichage</label>
                <input id="sort_order" name="sort_order" type="number" min="0" max="999" value="{{ old('sort_order', 0) }}">
            </div>
        </div>
        <p style="margin: 14px 0 0;">
            <label style="display: inline;">
                <input type="checkbox" name="recurring" value="1" style="width: auto;" @checked(old('recurring'))>
                Récurrente : une nouvelle édition s’ouvre dès que le tirage est révélé
            </label>
        </p>
        <p style="margin: 8px 0 0;">
            <label style="display: inline;">
                <input type="checkbox" name="active" value="1" style="width: auto;" @checked(old('active', true))>
                Proposée dans l’application
            </label>
        </p>
        <p style="margin: 8px 0 0;">
            <label for="description">Description</label>
            <textarea id="description" name="description" rows="2" maxlength="1000">{{ old('description') }}</textarea>
        </p>
        <p style="margin: 16px 0 0;"><button type="submit">Créer le modèle</button></p>
        <p class="aide">
            La répartition s’écrit en pourcentages séparés par des barres, une part par gagnant,
            et doit totaliser 100. Laissée vide, elle est calculée automatiquement.
        </p>
    </form>

    <h3>Modèles existants</h3>
    @if($templates->isEmpty())
        <p class="aide">Aucun modèle pour l’instant. Les responsables créent leurs cagnottes champ par champ.</p>
    @else
        <table>
            <thead>
            <tr>
                <th>Nom</th><th>Type</th><th>Durée</th><th class="nombre">Ticket</th>
                <th class="nombre">Gagnants</th><th>Répartition</th><th>État</th><th></th>
            </tr>
            </thead>
            <tbody>
            @foreach($templates as $template)
                <tr>
                    <td>
                        <strong>{{ $template->name }}</strong>
                        @if($template->recurring)<span class="etiquette vert">récurrente</span>@endif
                        @if($template->description)<div class="aide">{{ $template->description }}</div>@endif
                    </td>
                    <td>{{ $template->mode->value === 'gagnants' ? 'à gagnants' : 'solidaire' }}</td>
                    <td>{{ str_replace('_', ' ', $template->duration->value) }}</td>
                    <td class="nombre">{{ $template->ticket_price ? number_format($template->ticket_price, 0, ',', ' ') : '—' }}</td>
                    <td class="nombre">{{ $template->winners_count ?? '—' }}</td>
                    <td>{{ $template->prize_split ? implode(' / ', $template->prize_split) : '—' }}</td>
                    <td>
                        @if($template->active)
                            <span class="etiquette vert">proposée</span>
                        @else
                            <span class="etiquette gris">retirée</span>
                        @endif
                    </td>
                    <td>
                        <form method="post" action="{{ route('admin.templates.destroy', $template) }}"
                              onsubmit="return confirm('Retirer ce modèle de la liste ?');">
                            @csrf
                            @method('delete')
                            <button class="discret" type="submit">Retirer</button>
                        </form>
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endif
@endsection
