<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tontines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('created_by')->constrained('users');
            $table->string('name');
            $table->string('type');
            // Montants en francs CFA entiers : pas de décimales.
            $table->unsignedInteger('amount');
            $table->string('frequency');
            $table->date('starts_on');
            $table->unsignedSmallInteger('cycles_count')->nullable();
            $table->unsignedSmallInteger('max_members')->nullable();
            $table->string('goal')->nullable();
            $table->string('status')->default('brouillon');
            $table->timestamp('started_at')->nullable();
            $table->timestamps();

            $table->index(['organization_id', 'status']);
        });

        Schema::create('tontine_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('tontine_id')->constrained();
            $table->foreignId('user_id')->constrained();
            $table->unsignedTinyInteger('shares')->default(1);
            $table->unsignedSmallInteger('position')->nullable();
            $table->timestamps();

            $table->unique(['tontine_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tontine_members');
        Schema::dropIfExists('tontines');
    }
};
