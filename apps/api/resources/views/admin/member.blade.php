@extends('admin.layout')

@section('title', $member->name ?? 'Membre')

@section('content')
    <h2>{{ $member->name ?? 'Compte sans nom' }}</h2>
    <p class="sous">
        {{ $member->phone }}
        @if($member->email) · {{ $member->email }} @endif
        · inscrit le {{ $member->created_at?->format('d/m/Y') }}
    </p>

    @if($member->blocked_at)
        <p class="erreurs">
            Compte suspendu le {{ $member->blocked_at->format('d/m/Y') }}.
            {{ $member->blocked_reason ? 'Motif : '.$member->blocked_reason : '' }}
            Son solde et son historique restent les siens.
        </p>
    @endif

    <div class="cartes">
        <div class="carte">
            <div class="valeur">@fcfa($balance)</div>
            <div class="cle">solde</div>
        </div>
        <div class="carte">
            <div class="valeur">niveau {{ $limits['level'] }}</div>
            <div class="cle">plafond {{ number_format($limits['balance'], 0, ',', ' ') }} FCFA</div>
        </div>
        <div class="carte">
            <div class="valeur">@fcfa($limits['daily_withdrawal'])</div>
            <div class="cle">retrait maximum par jour</div>
        </div>
        <div class="carte">
            <div class="valeur">{{ $member->payout_phone ?? '—' }}</div>
            <div class="cle">numéro de retrait</div>
        </div>
    </div>

    <h3>Décisions</h3>
    <form class="bloc" method="post" action="{{ route('admin.members.update', $member) }}">
        @csrf
        @method('put')
        <div class="champs">
            <div>
                <label for="action">Action</label>
                <select id="action" name="action">
                    @if($member->blocked_at)
                        <option value="debloquer">Lever la suspension</option>
                    @else
                        <option value="bloquer">Suspendre le compte</option>
                    @endif
                    @if($member->wallet_verified_at)
                        <option value="retirer_verification">Retirer la vérification d’identité</option>
                    @else
                        <option value="verifier">Vérifier l’identité (niveau 2)</option>
                    @endif
                </select>
            </div>
            <div style="grid-column: span 2;">
                <label for="reason">Motif</label>
                <input id="reason" name="reason" maxlength="200" placeholder="Ce qui a été constaté">
            </div>
            <div style="align-self: end;"><button type="submit">Appliquer</button></div>
        </div>
        <p class="aide">
            Suspendre coupe la connexion et les jetons en cours. Cela n’efface ni le solde, ni les
            cotisations, ni les tontines auxquelles ce compte participe.
        </p>
    </form>

    <h3>Organisations</h3>
    @if($organizations->isEmpty())
        <p class="aide">Ce compte n’appartient à aucun groupement.</p>
    @else
        <table>
            <thead><tr><th>Nom</th><th>Rôle</th><th>Type</th></tr></thead>
            <tbody>
            @foreach($organizations as $organization)
                <tr>
                    <td>{{ $organization->name }}</td>
                    <td>{{ $organization->pivot->role }}</td>
                    <td>{{ $organization->isPersonal() ? 'espace personnel' : 'groupement' }}</td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endif

    <h3>Mouvements du portefeuille</h3>
    @if($transactions->isEmpty())
        <p class="aide">Aucun mouvement.</p>
    @else
        <table>
            <thead>
            <tr><th>Date</th><th>Opération</th><th class="nombre">Montant</th><th class="nombre">Frais</th>
                <th class="nombre">Solde après</th><th>État</th><th>Détail</th></tr>
            </thead>
            <tbody>
            @foreach($transactions as $transaction)
                <tr>
                    <td>{{ $transaction->created_at?->timezone('Africa/Ouagadougou')->format('d/m H\hi') }}</td>
                    <td>{{ $transaction->type->label() }}</td>
                    <td class="nombre">{{ number_format($transaction->signedAmount(), 0, ',', ' ') }}</td>
                    <td class="nombre">{{ $transaction->fee_amount ?: '—' }}</td>
                    <td class="nombre">{{ $transaction->balance_after === null ? '—' : number_format($transaction->balance_after, 0, ',', ' ') }}</td>
                    <td>{{ $transaction->status->label() }}</td>
                    <td>{{ $transaction->description ?: '—' }}{{ $transaction->failure_reason ? ' — '.$transaction->failure_reason : '' }}</td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endif
@endsection
