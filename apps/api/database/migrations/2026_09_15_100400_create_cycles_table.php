<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cycles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('tontine_id')->constrained();
            $table->unsignedSmallInteger('number');
            $table->date('due_on');
            $table->foreignId('beneficiary_member_id')->nullable()->constrained('tontine_members');
            $table->timestamps();

            $table->unique(['tontine_id', 'number']);
        });

        Schema::create('contributions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->constrained();
            $table->foreignId('cycle_id')->constrained();
            $table->foreignId('tontine_member_id')->constrained();
            $table->unsignedInteger('amount_due');
            $table->unsignedInteger('amount_paid')->default(0);
            $table->string('method')->nullable();
            $table->string('reference', 100)->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->foreignId('recorded_by')->nullable()->constrained('users');
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamps();

            $table->unique(['cycle_id', 'tontine_member_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contributions');
        Schema::dropIfExists('cycles');
    }
};
