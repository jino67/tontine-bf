<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tontine BF : {{ $cancelled ? 'paiement annulé' : 'paiement reçu' }}</title>
    <style>
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #F3F6F1; color: #12352A;
               font: 17px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; padding: 24px; box-sizing: border-box; }
        main { max-width: 420px; background: #fff; border: 1px solid #D5DED6; border-radius: 20px; padding: 28px; text-align: center; }
        h1 { font-size: 24px; margin: 0 0 8px; color: {{ $cancelled ? '#B83227' : '#155C39' }}; }
        p { margin: 0; color: #55655D; }
    </style>
</head>
<body>
<main>
    @if ($cancelled)
        <h1>Paiement annulé</h1>
        <p>Aucune somme n’a été prélevée. Revenez dans l’application Tontine BF pour réessayer.</p>
    @else
        <h1>Merci, paiement transmis</h1>
        <p>Revenez dans l’application Tontine BF : votre paiement y apparaît dès que PayDunya l’a validé.</p>
    @endif
</main>
</body>
</html>
