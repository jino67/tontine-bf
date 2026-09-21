<?php

use App\Enums\FeeOperation;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Frais de service. Les taux ne sont jamais écrits en dur dans le code : ils vivent
     * dans `fee_rules`, et chaque prélèvement garde dans `fee_charges` la règle qui l'a produit,
     * pour qu'un montant facturé il y a six mois reste explicable.
     */
    public function up(): void
    {
        Schema::create('fee_rules', function (Blueprint $table) {
            $table->id();
            $table->string('operation', 40);
            // Règle propre à une organisation : elle l'emporte sur la règle générale.
            $table->foreignId('organization_id')->nullable()->constrained()->nullOnDelete();
            $table->string('label')->nullable();
            // Taux en points de base : 325 vaut 3,25 %. Aucun flottant, jamais.
            $table->unsignedInteger('rate_bp')->default(0);
            $table->unsignedInteger('fixed_amount')->default(0);
            $table->unsignedInteger('min_amount')->default(0);
            $table->unsignedInteger('max_amount')->nullable();
            $table->string('payer', 20)->default('payeur');
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->boolean('active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['operation', 'active']);
        });

        Schema::create('fee_charges', function (Blueprint $table) {
            $table->id();
            $table->foreignId('organization_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('fee_rule_id')->nullable()->constrained()->nullOnDelete();
            $table->string('operation', 40);
            $table->nullableMorphs('chargeable');
            $table->unsignedInteger('base_amount');
            $table->unsignedInteger('fee_amount');
            $table->unsignedInteger('rate_bp')->default(0);
            $table->unsignedInteger('fixed_amount')->default(0);
            $table->string('payer', 20)->default('payeur');
            // Estimation de ce que l'opération coûte chez PayDunya, et marge qui en découle.
            $table->integer('provider_cost')->default(0);
            $table->integer('platform_margin')->default(0);
            $table->string('note')->nullable();
            $table->timestamps();

            $table->index(['operation', 'created_at']);
        });

        $now = now();
        $rules = [];

        foreach (FeeOperation::cases() as $operation) {
            $defaults = $operation->defaults();
            $rules[] = [
                'operation' => $operation->value,
                'organization_id' => null,
                'label' => $operation->label(),
                'rate_bp' => $defaults['rate_bp'],
                'fixed_amount' => $defaults['fixed_amount'],
                'min_amount' => $defaults['min_amount'],
                'max_amount' => $defaults['max_amount'],
                'payer' => $defaults['payer']->value,
                'starts_at' => $now,
                'ends_at' => null,
                'active' => true,
                'created_by' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        DB::table('fee_rules')->insert($rules);
    }

    public function down(): void
    {
        Schema::dropIfExists('fee_charges');
        Schema::dropIfExists('fee_rules');
    }
};
