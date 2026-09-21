<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tontine BF</title>
</head>
<body style="margin:0;padding:24px 12px;background:#f4f1ea;font-family:Arial,Helvetica,sans-serif;color:#1d2621;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
        <tr>
            <td align="center">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:12px;">
                    <tr>
                        <td style="padding:28px 28px 4px;font-size:18px;font-weight:bold;">Tontine BF</td>
                    </tr>
                    <tr>
                        <td style="padding:4px 28px 16px;font-size:16px;line-height:1.5;">
                            {{ $name ? 'Bonjour '.$name.',' : 'Bonjour,' }}
                        </td>
                    </tr>
                    @foreach($notifications as $notification)
                        <tr>
                            <td style="padding:0 28px 14px;">
                                <div style="padding:14px 16px;background:#f4f1ea;border-radius:8px;">
                                    <div style="font-size:15px;font-weight:bold;">{{ $notification->title }}</div>
                                    <div style="font-size:15px;line-height:1.5;padding-top:4px;">{{ $notification->body }}</div>
                                </div>
                            </td>
                        </tr>
                    @endforeach
                    <tr>
                        <td style="padding:6px 28px 8px;font-size:15px;line-height:1.5;">
                            Ouvrez l’application Tontine BF pour agir.
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:8px 28px 28px;font-size:14px;line-height:1.5;color:#5b665f;">
                            Pour ne plus recevoir ces messages, changez vos réglages dans l’application,
                            rubrique Profil, Notifications. Vous pouvez aussi couper les relances d’une
                            tontine précise sans couper les autres.
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
