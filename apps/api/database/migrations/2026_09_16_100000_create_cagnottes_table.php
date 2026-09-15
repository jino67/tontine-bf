<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cagnottes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('created_by')->constrained('users');
            // solidaire : remise à un bénéficiaire. gagnants : tickets et tirage au sort.
            $table->string('mode')->default('solidaire');
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('duration');
            $table->unsignedInteger('target_amount')->nullable();
            $table->unsignedInteger('min_amount')->default(100);
            $table->foreignId('beneficiary_user_id')->nullable()->constrained('users');
            $table->string('beneficiary_name')->nullable();
            $table->timestamp('opens_at');
            $table->timestamp('ends_at');
            $table->string('status')->default('ouverte');
            $table->timestamp('closed_at')->nullable();

            // Mode solidaire : remise des fonds.
            $table->unsignedInteger('handover_amount')->nullable();
            $table->string('handover_method')->nullable();
            $table->string('handover_reference', 100)->nullable();
            $table->timestamp('handed_over_at')->nullable();
            $table->foreignId('handover_recorded_by')->nullable()->constrained('users');
            $table->timestamp('handover_confirmed_at')->nullable();

            // Mode gagnants : tickets, répartition, rangs attribués publiquement, tirage vérifiable.
            $table->unsignedInteger('ticket_price')->nullable();
            $table->unsignedTinyInteger('winners_count')->nullable();
            $table->json('prize_split')->nullable();
            $table->unsignedTinyInteger('fee_percent')->default(0);
            $table->json('designations')->nullable();
            $table->text('draw_seed')->nullable();
            $table->string('draw_seed_hash', 64)->nullable();
            $table->json('draw_tickets')->nullable();
            $table->timestamp('draw_reveal_after')->nullable();
            $table->timestamp('drawn_at')->nullable();

            $table->timestamps();

            $table->index(['organization_id', 'status']);
        });

        Schema::create('cagnotte_contributions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('cagnotte_id')->constrained();
            $table->foreignId('user_id')->constrained();
            $table->unsignedInteger('amount');
            $table->unsignedInteger('tickets')->default(0);
            $table->string('method');
            $table->string('reference', 100)->nullable();
            $table->timestamp('paid_at');
            $table->foreignId('recorded_by')->constrained('users');
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('cagnotte_winners', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('cagnotte_id')->constrained();
            $table->unsignedTinyInteger('rank');
            $table->foreignId('user_id')->constrained();
            $table->unsignedInteger('prize_amount');
            $table->boolean('designated')->default(false);
            $table->timestamp('paid_at')->nullable();
            $table->string('paid_method')->nullable();
            $table->string('paid_reference', 100)->nullable();
            $table->foreignId('paid_by')->nullable()->constrained('users');
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamps();

            $table->unique(['cagnotte_id', 'rank']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cagnotte_winners');
        Schema::dropIfExists('cagnotte_contributions');
        Schema::dropIfExists('cagnottes');
    }
};
