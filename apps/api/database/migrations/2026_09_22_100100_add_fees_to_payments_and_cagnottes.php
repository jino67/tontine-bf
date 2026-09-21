<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Un paiement en ligne porte désormais deux montants : ce qui revient à la tontine
     * ou à la cagnotte (`base_amount`), et les frais de service (`fee_amount`).
     * `amount` reste ce que le membre débourse, c'est-à-dire la somme des deux.
     */
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->unsignedInteger('base_amount')->default(0)->after('amount');
            $table->unsignedInteger('fee_amount')->default(0)->after('base_amount');
            $table->string('fee_operation', 40)->nullable()->after('fee_amount');
            $table->foreignId('fee_rule_id')->nullable()->after('fee_operation')->constrained()->nullOnDelete();
        });

        // Les paiements déjà enregistrés n'avaient pas de frais : la base vaut le montant.
        DB::table('payments')->update(['base_amount' => DB::raw('amount')]);

        Schema::table('cagnottes', function (Blueprint $table) {
            // Part de la plateforme figée à la création, pour que le pot reste calculable à l'identique.
            $table->unsignedInteger('platform_fee_bp')->default(0)->after('fee_percent');
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('fee_rule_id');
            $table->dropColumn(['base_amount', 'fee_amount', 'fee_operation']);
        });

        Schema::table('cagnottes', function (Blueprint $table) {
            $table->dropColumn('platform_fee_bp');
        });
    }
};
