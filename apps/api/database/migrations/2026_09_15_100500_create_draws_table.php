<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('draws', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('tontine_id')->unique()->constrained();
            $table->foreignId('created_by')->constrained('users');
            // Graine chiffrée tant qu'elle n'est pas révélée, empreinte publiée dès l'engagement.
            $table->text('seed');
            $table->string('seed_hash', 64);
            $table->json('slots');
            $table->json('result')->nullable();
            $table->timestamp('reveal_after');
            $table->timestamp('revealed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('draws');
    }
};
