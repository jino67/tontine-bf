<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Back-office · Tontine BF</title>
    <style>
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #F3F6F1; color: #1B2420;
               font: 15px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; padding: 20px; }
        form { background: #fff; border: 1px solid #DDE4DC; border-radius: 16px; padding: 28px; width: min(380px, 100%); }
        h1 { font-size: 20px; margin: 0 0 2px; }
        p.sous { color: #6B7A72; margin: 0 0 22px; font-size: 14px; }
        label { display: block; font-size: 13px; color: #6B7A72; margin: 14px 0 4px; }
        input { width: 100%; padding: 10px 12px; border: 1px solid #DDE4DC; border-radius: 8px; font: inherit; }
        button { width: 100%; margin-top: 20px; background: #1E7A4C; color: #fff; border: 0;
                 border-radius: 8px; padding: 11px; font: inherit; font-weight: 600; cursor: pointer; }
        .erreurs { background: #F8E7E5; border-left: 3px solid #B83227; padding: 10px 12px;
                   border-radius: 8px; margin-bottom: 4px; font-size: 14px; }
        .erreurs ul { margin: 4px 0 0 18px; padding: 0; }
    </style>
</head>
<body>
<form method="post" action="{{ route('admin.login.store') }}">
    @csrf
    <h1>Back-office Tontine BF</h1>
    <p class="sous">Réservé aux administrateurs de la plateforme.</p>

    @if($errors->any())
        <div class="erreurs">
            <ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul>
        </div>
    @endif

    <label for="phone">Numéro de téléphone</label>
    <input id="phone" name="phone" inputmode="tel" autocomplete="username" value="{{ old('phone') }}" required autofocus>

    <label for="password">Mot de passe</label>
    <input id="password" name="password" type="password" autocomplete="current-password" required>

    <button type="submit">Entrer</button>
</form>
</body>
</html>
