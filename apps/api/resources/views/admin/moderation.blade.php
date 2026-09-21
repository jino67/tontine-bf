@extends('admin.layout')

@section('title', 'Signalements')

@section('content')
    <h2>Signalements</h2>
    <p class="sous">
        Trois signalements distincts masquent déjà une fiche automatiquement. Ici, on confirme
        ce masquage ou on le lève. Masquer ne supprime rien : les membres déjà entrés gardent
        leur place, leur argent et leur historique.
    </p>

    <p>
        <a href="{{ route('admin.moderation.index') }}">À traiter ({{ $pendingCount }})</a>
        &nbsp;·&nbsp;
        <a href="{{ route('admin.moderation.index', ['etat' => 'traites']) }}">Déjà traités</a>
    </p>

    @if($groups->isEmpty())
        <p class="aide">{{ $treated ? 'Aucun signalement traité.' : 'Aucun signalement en attente. ' }}</p>
    @endif

    @foreach($groups as $group)
        @php($target = $group['target'])
        <h3>
            {{ $target->title ?? $target->name ?? 'Fiche supprimée' }}
            <span class="etiquette gris">{{ $group['kind'] === 'Cagnotte' ? 'cagnotte' : 'tontine' }}</span>
            @if($group['hidden'])<span class="etiquette rouge">masquée</span>@endif
            <span class="etiquette {{ $group['count'] >= 3 ? 'rouge' : 'gris' }}">
                {{ $group['count'] }} signalement{{ $group['count'] > 1 ? 's' : '' }}
            </span>
        </h3>

        <table>
            <thead><tr><th>Motif</th><th>Précision</th><th>Signalé par</th><th>Date</th></tr></thead>
            <tbody>
            @foreach($group['reports'] as $report)
                <tr>
                    <td>{{ $report->reason->label() }}</td>
                    <td>{{ $report->note ?: '—' }}</td>
                    <td>{{ $report->user?->name ?? 'Membre' }}</td>
                    <td>{{ $report->created_at?->timezone('Africa/Ouagadougou')->format('d/m/Y H\hi') }}</td>
                </tr>
            @endforeach
            </tbody>
        </table>

        @php($first = $group['reports']->first())
        @if($target !== null && ! $treated)
            <form method="post" action="{{ route('admin.moderation.update', $first) }}" style="margin-top: 12px;">
                @csrf
                @method('put')
                <div class="champs">
                    <div>
                        <label for="decision-{{ $first->id }}">Décision</label>
                        <select id="decision-{{ $first->id }}" name="decision">
                            <option value="masquee">Masquer la fiche</option>
                            <option value="conservee">Rétablir la fiche</option>
                        </select>
                    </div>
                    <div style="grid-column: span 2;">
                        <label for="note-{{ $first->id }}">Motif de la décision</label>
                        <input id="note-{{ $first->id }}" name="note" maxlength="500" placeholder="Ce qui a été vérifié">
                    </div>
                </div>
                <p style="margin: 14px 0 0;"><button type="submit">Trancher</button></p>
            </form>
        @endif
    @endforeach
@endsection
