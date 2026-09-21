<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Notifications et relances.
     *
     * Chaque envoi est tracé : quoi, à qui, quand, par quel canal, avec quel résultat.
     * Sans cette trace, impossible de prouver qu'un membre a bien été prévenu avant une
     * exclusion, et la relance devient parole contre parole.
     */
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('organization_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 40);
            $table->string('channel', 20)->default('application');
            $table->string('status', 20)->default('en_attente');
            $table->string('title');
            $table->text('body');
            $table->nullableMorphs('related');
            // Empreinte du message : deux fois le même dans la journée, c'est du spam.
            $table->string('dedupe_key', 120)->nullable();
            // Heures décentes : ce qui tombe la nuit attend le matin.
            $table->timestamp('send_after')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('read_at')->nullable();
            $table->string('failure_reason')->nullable();
            $table->json('payload')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'read_at']);
            $table->index(['status', 'send_after']);
            $table->unique(['user_id', 'dedupe_key']);
        });

        Schema::create('notification_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->boolean('reminders')->default(true);
            $table->boolean('mail')->default(true);
            $table->boolean('push')->default(true);
            $table->boolean('whatsapp')->default(true);
            $table->boolean('sms')->default(false);
            // Objets pour lesquels ce membre ne veut plus être relancé : « tontine:12 ».
            $table->json('muted')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_settings');
        Schema::dropIfExists('notifications');
    }
};
