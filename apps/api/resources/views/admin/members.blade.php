@extends('admin.layout')

@section('title', 'Membres')

@section('content')
    <h2>Membres</h2>
    <p class="sous">Recherche par numéro, nom ou adresse e-mail.</p>

    <form class="bloc" method="get" action="{{ route('admin.members.index') }}">
        <div class="champs">
            <div style="grid-column: span 2;">
                <label for="q">Rechercher</label>
                <input id="q" name="q" value="{{ $search }}" placeholder="70 12 34 56, Awa, awa@exemple.bf">
            </div>
            <div style="align-self: end;"><button type="submit">Chercher</button></div>
        </div>
    </form>

    <h3>{{ $members->count() }} compte{{ $members->count() > 1 ? 's' : '' }}</h3>
    @if($members->isEmpty())
        <p class="aide">Aucun compte ne correspond.</p>
    @else
        <table>
            <thead>
            <tr><th>Nom</th><th>Numéro</th><th>E-mail</th><th class="nombre">Groupes</th><th>Inscrit le</th><th>État</th></tr>
            </thead>
            <tbody>
            @foreach($members as $member)
                <tr>
                    <td><a href="{{ route('admin.members.show', $member) }}">{{ $member->name ?? 'Sans nom' }}</a></td>
                    <td>{{ $member->phone }}</td>
                    <td>{{ $member->email ?? '—' }}</td>
                    <td class="nombre">{{ $member->memberships_count }}</td>
                    <td>{{ $member->created_at?->format('d/m/Y') }}</td>
                    <td>
                        @if($member->blocked_at)<span class="etiquette rouge">suspendu</span>@endif
                        @if($member->is_super_admin)<span class="etiquette vert">administrateur</span>@endif
                        @if($member->wallet_verified_at)<span class="etiquette vert">vérifié</span>@endif
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    @endif
@endsection
