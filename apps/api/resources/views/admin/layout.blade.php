<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Back-office') · Tontine BF</title>
    <style>
        :root {
            --feuille: #1E7A4C; --feuille-clair: #E8F1EA; --or: #E0A526; --indigo: #2F3E8F;
            --piment: #B83227; --coton: #F3F6F1; --encre: #1B2420; --gris: #6B7A72; --ligne: #DDE4DC;
        }
        * { box-sizing: border-box; }
        body { margin: 0; background: var(--coton); color: var(--encre);
               font: 15px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
        a { color: var(--feuille); }
        .shell { display: flex; min-height: 100vh; }
        aside { width: 230px; background: #fff; border-right: 1px solid var(--ligne); padding: 20px 0; flex-shrink: 0; }
        aside h1 { font-size: 17px; margin: 0 20px 20px; }
        aside h1 span { display: block; font-size: 12px; color: var(--gris); font-weight: normal; }
        nav a { display: block; padding: 10px 20px; color: var(--encre); text-decoration: none; border-left: 3px solid transparent; }
        nav a:hover { background: var(--coton); }
        nav a.on { border-left-color: var(--feuille); background: var(--feuille-clair); font-weight: 600; }
        nav .pastille { float: right; background: var(--piment); color: #fff; border-radius: 99px; padding: 0 7px; font-size: 12px; }
        main { flex: 1; padding: 28px 32px; max-width: 1100px; }
        h2 { margin: 0 0 4px; font-size: 24px; }
        h3 { margin: 28px 0 10px; font-size: 17px; }
        .sous { color: var(--gris); margin: 0 0 22px; }
        .cartes { display: grid; grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); gap: 14px; }
        .carte { background: #fff; border: 1px solid var(--ligne); border-radius: 12px; padding: 14px 16px; }
        .carte .valeur { font-size: 22px; font-weight: 700; font-variant-numeric: tabular-nums; }
        .carte .cle { color: var(--gris); font-size: 13px; }
        .carte.alerte { border-color: var(--piment); }
        .carte.alerte .valeur { color: var(--piment); }
        table { width: 100%; border-collapse: collapse; background: #fff;
                border: 1px solid var(--ligne); border-radius: 12px; overflow: hidden; }
        th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--ligne); vertical-align: top; }
        th { background: var(--coton); font-size: 13px; color: var(--gris); text-transform: uppercase; letter-spacing: .03em; }
        tr:last-child td { border-bottom: none; }
        td.nombre, th.nombre { text-align: right; font-variant-numeric: tabular-nums; }
        form.bloc { background: #fff; border: 1px solid var(--ligne); border-radius: 12px; padding: 18px; }
        .champs { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 12px; }
        label { display: block; font-size: 13px; color: var(--gris); margin-bottom: 4px; }
        input, select, textarea { width: 100%; padding: 8px 10px; border: 1px solid var(--ligne);
                                  border-radius: 8px; font: inherit; background: #fff; }
        button { background: var(--feuille); color: #fff; border: 0; border-radius: 8px;
                 padding: 9px 16px; font: inherit; font-weight: 600; cursor: pointer; }
        button.discret { background: #fff; color: var(--encre); border: 1px solid var(--ligne); }
        button.danger { background: var(--piment); }
        .etiquette { display: inline-block; padding: 1px 8px; border-radius: 99px; font-size: 12px; font-weight: 600; }
        .etiquette.vert { background: var(--feuille-clair); color: var(--feuille); }
        .etiquette.rouge { background: #F8E7E5; color: var(--piment); }
        .etiquette.gris { background: var(--coton); color: var(--gris); }
        .avis { background: var(--feuille-clair); border-left: 3px solid var(--feuille);
                padding: 10px 14px; border-radius: 8px; margin-bottom: 18px; }
        .erreurs { background: #F8E7E5; border-left: 3px solid var(--piment);
                   padding: 10px 14px; border-radius: 8px; margin-bottom: 18px; }
        .erreurs ul { margin: 4px 0 0 18px; padding: 0; }
        .aide { color: var(--gris); font-size: 13px; margin-top: 6px; }
        @media (max-width: 760px) {
            .shell { display: block; }
            aside { width: auto; border-right: 0; border-bottom: 1px solid var(--ligne); }
            nav { display: flex; flex-wrap: wrap; }
            main { padding: 20px; }
        }
    </style>
</head>
<body>
<div class="shell">
    <aside>
        <h1>Tontine BF<span>back-office</span></h1>
        <nav>
            @php($route = request()->route()?->getName())
            <a href="{{ route('admin.dashboard') }}" class="{{ $route === 'admin.dashboard' ? 'on' : '' }}">Tableau de bord</a>
            <a href="{{ route('admin.moderation.index') }}" class="{{ str_starts_with((string) $route, 'admin.moderation') ? 'on' : '' }}">
                Signalements
                @if(($pendingReports ?? 0) > 0)<span class="pastille">{{ $pendingReports }}</span>@endif
            </a>
            <a href="{{ route('admin.templates.index') }}" class="{{ str_starts_with((string) $route, 'admin.templates') ? 'on' : '' }}">Modèles de cagnotte</a>
            <a href="{{ route('admin.fees.index') }}" class="{{ str_starts_with((string) $route, 'admin.fees') ? 'on' : '' }}">Frais de service</a>
            <a href="{{ route('admin.wallet.index') }}" class="{{ str_starts_with((string) $route, 'admin.wallet') ? 'on' : '' }}">Portefeuilles</a>
            <a href="{{ route('admin.members.index') }}" class="{{ str_starts_with((string) $route, 'admin.members') ? 'on' : '' }}">Membres</a>
        </nav>
        <form method="post" action="{{ route('admin.logout') }}" style="padding: 18px 20px 0;">
            @csrf
            <button class="discret" type="submit">Se déconnecter</button>
        </form>
    </aside>
    <main>
        @if(session('status'))<p class="avis">{{ session('status') }}</p>@endif
        @if($errors->any())
            <div class="erreurs">
                <strong>Rien n’a été enregistré :</strong>
                <ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul>
            </div>
        @endif
        @yield('content')
    </main>
</div>
</body>
</html>
