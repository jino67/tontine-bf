<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Portefeuille, tenu en comptabilité à double entrée.
     *
     * Chaque mouvement écrit deux lignes égales et opposées dans `ledger_entries` : c'est la seule
     * façon de prouver, des mois plus tard, où est passé chaque franc. Le solde d'un compte est
     * toujours la somme de ses écritures, jamais une colonne que l'on pourrait corriger à la main.
     * `wallet_transactions` n'est que la lecture lisible de ces écritures, côté membre.
     */
    public function up(): void
    {
        Schema::create('accounts', function (Blueprint $table) {
            $table->id();
            // « membre:12 », « organisation:3 », « cagnotte:7 », « revenus », « reglement:paydunya ».
            $table->string('code', 60)->unique();
            $table->string('kind', 20);
            $table->nullableMorphs('owner');
            $table->string('currency', 3)->default('XOF');
            $table->string('label')->nullable();
            $table->timestamps();
        });

        Schema::create('ledger_entries', function (Blueprint $table) {
            $table->id();
            // Toutes les lignes d'un même mouvement partagent cette référence.
            $table->string('transaction_ref', 40);
            $table->foreignId('account_id')->constrained();
            $table->string('direction', 6);
            $table->unsignedInteger('amount');
            $table->nullableMorphs('reference');
            $table->string('memo')->nullable();
            // Aucune date de modification : une écriture ne se corrige pas, elle se contrepasse.
            $table->timestamp('created_at')->nullable();

            $table->index(['account_id', 'id']);
            $table->index('transaction_ref');
        });

        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->string('reference', 40)->unique();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('organization_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 30);
            $table->string('status', 20)->default('reussie');
            // Sens vu du membre : crédit quand son solde augmente.
            $table->string('direction', 6);
            $table->unsignedInteger('amount');
            $table->unsignedInteger('fee_amount')->default(0);
            $table->integer('balance_after')->nullable();
            $table->foreignId('counterparty_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->nullableMorphs('related');
            $table->foreignId('payment_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('payout_id')->nullable()->constrained()->nullOnDelete();
            $table->string('description')->nullable();
            $table->string('failure_reason')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'id']);
        });

        // Un dépôt et un retrait sont personnels : ils ne relèvent d'aucune organisation.
        Schema::table('payments', function (Blueprint $table) {
            $table->foreignId('organization_id')->nullable()->change();
        });

        Schema::table('payouts', function (Blueprint $table) {
            $table->foreignId('organization_id')->nullable()->change();
        });

        Schema::table('users', function (Blueprint $table) {
            // Numéro de retrait, vérifié une fois puis réutilisé.
            $table->string('payout_phone', 20)->nullable();
            $table->string('payout_mode', 40)->nullable();
            $table->timestamp('payout_changed_at')->nullable();
            // Niveau 2 du portefeuille : pièce d'identité contrôlée par le back-office.
            $table->timestamp('wallet_verified_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['payout_phone', 'payout_mode', 'payout_changed_at', 'wallet_verified_at']);
        });

        Schema::dropIfExists('wallet_transactions');
        Schema::dropIfExists('ledger_entries');
        Schema::dropIfExists('accounts');
    }
};
