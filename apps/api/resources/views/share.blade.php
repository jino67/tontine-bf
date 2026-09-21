@php
    $money = fn (?int $amount) => $amount === null ? null : number_format($amount, 0, ',', ' ').' FCFA';
    $title = match ($type) {
        'tontine' => $item['name'],
        'cagnotte' => $item['title'],
        'invitation' => $item['tontine'] ?? $item['organization'],
        default => $item['name'],
    };
    $lines = match ($type) {
        'tontine' => array_filter([
            'Cotisation' => $money($item['amount']).' par '.match ($item['frequency']) {
                'quotidien' => 'jour',
                'mensuel' => 'mois',
                default => 'semaine',
            },
            'Membres' => $item['members_count'].($item['places_left'] === null ? '' : ' inscrits, '.$item['places_left'].' place(s) restante(s)'),
            'Démarrage' => $item['started'] ? 'déjà démarrée' : \Illuminate\Support\Carbon::parse($item['starts_on'])->translatedFormat('d F Y'),
            'Organisation' => $item['organization'],
            'Créée par' => $item['creator'],
        ]),
        'cagnotte' => array_filter([
            'Réunis' => $money($item['collected_amount']),
            'Objectif' => $money($item['target_amount']),
            'Ticket' => $money($item['ticket_price']),
            'Gagnants' => $item['winners_count'],
            'Participations' => $item['contributions_count'],
            'Organisation' => $item['organization'],
        ]),
        'organisation' => array_filter([
            'Membres' => $item['members_count'],
        ]),
        default => array_filter([
            'Organisation' => $item['organization'],
            'Tontine' => $item['tontine'],
        ]),
    };
    $subtitle = match ($type) {
        'tontine' => $item['accepts_requests']
            ? 'Cette tontine accepte les demandes d’adhésion.'
            : ($item['started'] ? 'Les inscriptions sont fermées depuis le démarrage.' : 'Les adhésions se font sur invitation.'),
        'cagnotte' => $item['status'] === 'ouverte' ? 'La cagnotte est ouverte aux participations.' : 'La cagnotte est clôturée.',
        'organisation' => $item['accepts_requests'] ? 'Cette organisation accepte les demandes d’adhésion.' : 'Cette organisation est sur invitation.',
        default => $item['usable'] ? 'Invitation valable : ouvrez l’application pour la rejoindre.' : 'Cette invitation n’est plus valable.',
    };
@endphp
<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tontine BF : {{ $title }}</title>
    <meta name="robots" content="noindex">
    <style>
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #F3F6F1; color: #12352A;
               font: 17px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; padding: 24px; box-sizing: border-box; }
        main { width: 100%; max-width: 440px; background: #fff; border: 1px solid #D5DED6; border-radius: 20px; padding: 28px; }
        .brand { font-size: 14px; letter-spacing: .08em; text-transform: uppercase; color: #8A9A90; margin: 0 0 14px; }
        h1 { font-size: 24px; margin: 0 0 6px; }
        .subtitle { margin: 0 0 20px; color: #55655D; }
        dl { display: grid; grid-template-columns: auto 1fr; gap: 8px 16px; margin: 0 0 24px; }
        dt { color: #8A9A90; font-size: 15px; }
        dd { margin: 0; text-align: right; font-weight: 600; }
        a.button { display: block; text-align: center; padding: 14px 18px; border-radius: 14px; text-decoration: none; font-weight: 600; }
        .primary { background: #12352A; color: #fff; }
        .secondary { background: #fff; color: #12352A; border: 1px solid #D5DED6; margin-top: 10px; }
        .code { margin: 22px 0 0; text-align: center; color: #55655D; font-size: 15px; }
        .code strong { font-family: ui-monospace, "SFMono-Regular", Consolas, monospace; letter-spacing: .12em; color: #12352A; }
    </style>
</head>
<body>
<main>
    <p class="brand">Tontine BF</p>
    <h1>{{ $title }}</h1>
    <p class="subtitle">{{ $subtitle }}</p>

    @if ($lines !== [])
        <dl>
            @foreach ($lines as $label => $value)
                <dt>{{ $label }}</dt>
                <dd>{{ $value }}</dd>
            @endforeach
        </dl>
    @endif

    <a class="button primary" href="{{ url()->current() }}">Ouvrir dans l’application</a>
    @if ($apkUrl)
        <a class="button secondary" href="{{ $apkUrl }}">Installer l’application</a>
    @endif

    <p class="code">Code à saisir dans l’application : <strong>{{ $code }}</strong></p>
</main>
</body>
</html>
