<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Paiements en ligne (PayDunya) : une cotisation de tontine ou une participation à une cagnotte.
        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->morphs('payable');
            $table->unsignedInteger('amount');
            $table->string('provider', 30)->default('paydunya');
            $table->string('token', 100)->nullable()->unique();
            $table->text('checkout_url')->nullable();
            $table->string('status', 20)->default('en_attente');
            $table->string('receipt_url', 500)->nullable();
            $table->string('failure_reason')->nullable();
            $table->json('payload')->nullable();
            $table->timestamp('paid_at')->nullable();
            // Vide si l'argent est reçu mais n'a pas pu être affecté (cotisation déjà confirmée, tirage lancé...).
            $table->timestamp('applied_at')->nullable();
            $table->timestamps();

            $table->index(['organization_id', 'status']);
        });

        // Remises par PayDunya : gain d'une cagnotte ou fonds d'une cagnotte solidaire.
        Schema::create('payouts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained()->cascadeOnDelete();
            $table->morphs('payable');
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('phone', 20);
            $table->string('withdraw_mode', 40);
            $table->unsignedInteger('amount');
            $table->string('disburse_id', 40)->unique();
            $table->string('token', 100)->nullable()->unique();
            $table->string('transaction_id', 100)->nullable();
            $table->string('status', 20)->default('en_cours');
            $table->string('failure_reason')->nullable();
            $table->json('payload')->nullable();
            $table->foreignId('initiated_by')->constrained('users');
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payouts');
        Schema::dropIfExists('payments');
    }
};
