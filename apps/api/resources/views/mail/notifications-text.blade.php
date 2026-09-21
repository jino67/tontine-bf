{{ $name ? 'Bonjour '.$name.',' : 'Bonjour,' }}

@foreach($notifications as $notification)
{{ $notification->title }}
{{ $notification->body }}

@endforeach
Ouvrez l'application Tontine BF pour agir.

Pour ne plus recevoir ces messages, changez vos réglages dans l'application,
rubrique Profil, Notifications.
