@extends('admin.layout')

@section('title', 'Tableau de bord')

@section('content')
    <h2>Tableau de bord</h2>
    <p class="sous">L’état de la plateforme au {{ now()->timezone('Africa/Ouagadougou')->format('d/m/Y à H\hi') }}.</p>

    <div class="cartes">
        @foreach($counts as $label => $value)
            <div class="carte">
                <div class="valeur">{{ number_format($value, 0, ',', ' ') }}</div>
                <div class="cle">{{ $label }}</div>
            </div>
        @endforeach
    </div>

    <h3>Argent</h3>
    <div class="cartes">
        @foreach($money as $label => $value)
            <div class="carte">
                <div class="valeur">@fcfa($value)</div>
                <div class="cle">{{ $label }}</div>
            </div>
        @endforeach
    </div>

    <h3>À surveiller</h3>
    <div class="cartes">
        @foreach($alerts as $label => $value)
            <div class="carte {{ $value > 0 ? 'alerte' : '' }}">
                <div class="valeur">{{ $label === 'compte d’attente' ? number_format($value, 0, ',', ' ') : $value }}</div>
                <div class="cle">{{ $label }}</div>
            </div>
        @endforeach
    </div>
    <p class="aide">
        Un paiement reçu mais non affecté veut dire que l’argent est bien arrivé sans trouver sa cotisation :
        il se rapproche à la main. Le compte d’attente porte les retraits partis chez PayDunya et pas encore réglés.
    </p>

    <h3>Derniers frais prélevés</h3>
    @if($recentCharges->isEmpty())
        <p class="aide">Aucun frais prélevé pour l’instant.</p>
    @else
        <table>
            <thead>
            <tr>
                <th>Date</th><th>Opération</th><th>Membre</th>
                <th class="nombre">Base</th><th class="nombre">Frais</th><th class="nombre">Marge</th>
            </tr>
            </thead>
            <tbody>
            @foreach($recentCharges as $charge)
                <tr>
                    <td>{{ $charge->created_at?->timezone('Africa/Ouagadougou')->format('d/m H\hi') }}</td>
                    <td>{{ $charge->operation->label() }}</td>
                    <td>{{ $charge->user?->name ?? '—' }}</td>
                    <td class="nombre">@fcfa($charge->base_amount)</td>
                    <td class="nombre">@fcfa($charge->fee_amount)</td>
                    <td class="nombre">@fcfa($charge->platform_margin)</td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endif
@endsection
