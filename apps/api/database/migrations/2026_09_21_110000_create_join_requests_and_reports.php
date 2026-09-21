<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Demande d'adhésion à une organisation ou à une tontine ouverte aux demandes.
        Schema::create('join_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tontine_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained();
            $table->string('message', 280)->nullable();
            $table->string('status', 20)->default('en_attente');
            $table->string('decision_reason', 280)->nullable();
            $table->foreignId('decided_by')->nullable()->constrained('users');
            $table->timestamp('decided_at')->nullable();
            $table->timestamps();

            $table->index(['organization_id', 'status']);
            $table->index(['user_id', 'status']);
        });

        // Signalement d'une fiche publique. Trois signalements distincts la masquent de l'annuaire.
        Schema::create('reports', function (Blueprint $table) {
            $table->id();
            $table->morphs('reportable');
            $table->foreignId('user_id')->constrained();
            $table->string('reason', 40);
            $table->string('note', 500)->nullable();
            $table->timestamps();

            $table->unique(['reportable_type', 'reportable_id', 'user_id']);
        });

        Schema::table('tontines', function (Blueprint $table) {
            $table->timestamp('hidden_at')->nullable();
        });

        Schema::table('cagnottes', function (Blueprint $table) {
            $table->timestamp('hidden_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('join_requests');
        Schema::dropIfExists('reports');

        Schema::table('tontines', function (Blueprint $table) {
            $table->dropColumn('hidden_at');
        });

        Schema::table('cagnottes', function (Blueprint $table) {
            $table->dropColumn('hidden_at');
        });
    }
};
