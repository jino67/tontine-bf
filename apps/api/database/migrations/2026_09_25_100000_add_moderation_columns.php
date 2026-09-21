<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Traces de modération.
     *
     * Un signalement traité garde qui a tranché, quand et pourquoi : sans cela, une fiche
     * masquée devient une décision sans auteur, impossible à expliquer à celui qui la conteste.
     */
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->timestamp('reviewed_at')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            // « masquee » ou « conservee ».
            $table->string('decision', 20)->nullable();
            $table->string('review_note', 500)->nullable();
        });

        Schema::table('users', function (Blueprint $table) {
            // Compte suspendu : il ne peut plus se connecter ni créer quoi que ce soit.
            $table->timestamp('blocked_at')->nullable();
            $table->string('blocked_reason')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reviewed_by');
            $table->dropColumn(['reviewed_at', 'decision', 'review_note']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['blocked_at', 'blocked_reason']);
        });
    }
};
