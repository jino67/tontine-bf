@extends('admin.layout')

@section('title', 'Portefeuilles')

@section('content')
    <h2>Portefeuilles</h2>
    <p class="sous">
        Le contrôle qui compte tient en une ligne : la somme de toutes les écritures doit être
        nulle. Si elle ne l’est pas, une écriture manque quelque part.
    </p>

    <div class="cartes">
        <div class="carte {{ $imbalance !== 0 ? 'alerte' : '' }}">
            <div class="valeur">{{ $imbalance === 0 ? 'équilibré' : number_format($imbalance, 0, ',', ' ') }}</div>
            <div class="cle">contrôle du grand livre</div>
        </div>
        @foreach($systemAccounts as $line)
            <div class="carte">
                <div class="valeur">@fcfa($line['balance'])</div>
                <div class="cle">{{ $line['account']->kind->label() }}</div>
            </div>
        @endforeach
    </div>

    <h3>Soldes par nature de compte</h3>
    <table>
        <thead><tr><th>Nature</th><th class="nombre">Comptes</th><th class="nombre">Solde</th></tr></thead>
        <tbody>
        @foreach($balances as $line)
            <tr>
                <td>{{ $line['kind']->label() }}</td>
                <td class="nombre">{{ $line['accounts'] }}</td>
                <td class="nombre">@fcfa($line['balance'])</td>
            </tr>
        @endforeach
        </tbody>
    </table>
    <p class="aide">
        Le solde des membres est ce que la plateforme leur doit. Il doit rester couvert par le
        compte de règlement PayDunya : c’est le rapprochement à faire chaque jour.
    </p>

    <h3>Retraits en attente</h3>
    @if($pending->isEmpty())
        <p class="aide">Aucun retrait en attente.</p>
    @else
        <table>
            <thead>
            <tr><th>Membre</th><th class="nombre">Montant</th><th class="nombre">Frais</th><th>Lancé le</th><th>Remise</th><th></th></tr>
            </thead>
            <tbody>
            @foreach($pending as $transaction)
                <tr>
                    <td>
                        <a href="{{ route('admin.members.show', $transaction->user_id) }}">
                            {{ $transaction->user?->name ?? $transaction->user?->phone }}
                        </a>
                    </td>
                    <td class="nombre">@fcfa($transaction->amount)</td>
                    <td class="nombre">@fcfa($transaction->fee_amount)</td>
                    <td>{{ $transaction->created_at?->timezone('Africa/Ouagadougou')->format('d/m/Y H\hi') }}</td>
                    <td>{{ $transaction->payout?->status->value ?? '—' }}</td>
                    <td>
                        <form method="post" action="{{ route('admin.wallet.refresh', $transaction) }}">
                            @csrf
                            <button class="discret" type="submit">Relire le statut</button>
                        </form>
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endif

    <h3>Dernières écritures</h3>
    <table>
        <thead>
        <tr><th>Date</th><th>Mouvement</th><th>Compte</th><th>Sens</th><th class="nombre">Montant</th><th>Objet</th></tr>
        </thead>
        <tbody>
        @foreach($entries as $entry)
            <tr>
                <td>{{ $entry->created_at?->timezone('Africa/Ouagadougou')->format('d/m H\hi') }}</td>
                <td><code>{{ $entry->transaction_ref }}</code></td>
                <td>{{ $entry->account->code }}</td>
                <td>{{ $entry->direction->value }}</td>
                <td class="nombre">@fcfa($entry->amount)</td>
                <td>{{ $entry->memo ?: '—' }}</td>
            </tr>
        @endforeach
        </tbody>
    </table>
@endsection
