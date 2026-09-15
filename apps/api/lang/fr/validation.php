<?php

// Messages des règles utilisées par l'API. Les règles absentes retombent sur l'anglais.
return [
    'after_or_equal' => 'Le champ :attribute ne peut pas être une date passée.',
    'before_or_equal' => 'Le champ :attribute ne peut pas être une date future.',
    'boolean' => 'Le champ :attribute doit valoir vrai ou faux.',
    'date' => "Le champ :attribute n'est pas une date valide.",
    'email' => 'Le champ :attribute doit être une adresse e-mail valide.',
    'enum' => 'La valeur choisie pour :attribute est invalide.',
    'exists' => 'La valeur choisie pour :attribute est invalide.',
    'in' => 'La valeur choisie pour :attribute est invalide.',
    'integer' => 'Le champ :attribute doit être un nombre entier.',
    'max' => [
        'array' => 'Le champ :attribute ne peut pas contenir plus de :max éléments.',
        'file' => 'Le fichier :attribute ne peut pas dépasser :max Ko.',
        'numeric' => 'Le champ :attribute ne peut pas dépasser :max.',
        'string' => 'Le champ :attribute ne peut pas dépasser :max caractères.',
    ],
    'min' => [
        'array' => 'Le champ :attribute doit contenir au moins :min éléments.',
        'file' => 'Le fichier :attribute doit faire au moins :min Ko.',
        'numeric' => 'Le champ :attribute doit être au moins égal à :min.',
        'string' => 'Le champ :attribute doit contenir au moins :min caractères.',
    ],
    'regex' => "Le format du champ :attribute n'est pas valide.",
    'required' => 'Le champ :attribute est obligatoire.',
    'required_unless' => 'Le champ :attribute est obligatoire.',
    'string' => 'Le champ :attribute doit être un texte.',

    'custom' => [
        'method' => [
            'required_unless' => 'Indiquez le moyen de paiement.',
        ],
    ],

    'attributes' => [
        'amount' => 'montant',
        'amount_paid' => 'montant payé',
        'code' => 'code',
        'cycles_count' => 'nombre de cycles',
        'device_name' => "nom de l'appareil",
        'email' => 'adresse e-mail',
        'expires_in_days' => 'durée de validité',
        'frequency' => 'fréquence',
        'goal' => 'objectif',
        'locale' => 'langue',
        'max_members' => 'nombre maximum de membres',
        'max_uses' => "nombre d'utilisations",
        'method' => 'moyen de paiement',
        'name' => 'nom',
        'paid_at' => 'date de paiement',
        'phone' => 'numéro de téléphone',
        'position' => 'position',
        'reference' => 'référence',
        'reveal_after' => 'date de révélation',
        'role' => 'rôle',
        'shares' => 'nombre de parts',
        'starts_on' => 'date de début',
        'tontine_id' => 'tontine',
        'type' => 'type',
        'user_id' => 'membre',
    ],
];
