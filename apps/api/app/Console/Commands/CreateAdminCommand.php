<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Support\PhoneNumber;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

/**
 * Crée ou promeut un administrateur du back-office.
 *
 * Sur un hébergement sans accès SSH, cette commande se lance une fois depuis une tâche
 * planifiée du panneau, comme les migrations.
 */
class CreateAdminCommand extends Command
{
    protected $signature = 'admin:create
        {--phone= : numéro de téléphone du compte}
        {--password= : mot de passe du back-office}
        {--name= : nom affiché}
        {--revoke : retire les droits au lieu de les donner}';

    protected $description = 'Donne ou retire l’accès au back-office pour un numéro de téléphone';

    public function handle(): int
    {
        $phone = PhoneNumber::normalize((string) $this->option('phone'));

        if ($phone === null) {
            $this->error('Numéro invalide. Attendu : 70123456 ou +22670123456.');

            return self::FAILURE;
        }

        if ($this->option('revoke')) {
            $user = User::where('phone', $phone)->first();

            if ($user === null) {
                $this->error('Aucun compte avec ce numéro.');

                return self::FAILURE;
            }

            $user->forceFill(['is_super_admin' => false, 'password' => null])->save();
            $this->info("Accès au back-office retiré à {$phone}.");

            return self::SUCCESS;
        }

        $password = (string) $this->option('password');

        if (strlen($password) < 10) {
            $this->error('Mot de passe trop court : 10 caractères au minimum.');

            return self::FAILURE;
        }

        $user = User::firstOrNew(['phone' => $phone]);
        $user->forceFill([
            'name' => $this->option('name') ?: ($user->name ?? 'Administration'),
            'password' => Hash::make($password),
            'is_super_admin' => true,
        ])->save();

        $this->info("Accès au back-office accordé à {$phone}.");
        $this->line('Connexion : '.rtrim((string) config('app.url'), '/').'/admin/connexion');

        return self::SUCCESS;
    }
}
