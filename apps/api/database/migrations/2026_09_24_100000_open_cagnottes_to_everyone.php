<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Les cagnottes s'ouvrent à tout le monde, et se relancent d'elles-mêmes.
     *
     * Une cagnotte récurrente n'est pas rouverte : une nouvelle édition est créée après le tirage,
     * et l'ancienne reste intacte avec ses participants, son tirage et ses gagnants. C'est ce qui
     * permet de remonter l'historique d'une série, édition par édition.
     */
    public function up(): void
    {
        Schema::create('cagnotte_templates', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->string('mode', 20)->default('gagnants');
            $table->string('duration', 20)->default('hebdo_7j');
            $table->unsignedInteger('custom_days')->nullable();
            $table->unsignedInteger('ticket_price')->nullable();
            $table->unsignedTinyInteger('winners_count')->nullable();
            $table->json('prize_split')->nullable();
            $table->unsignedInteger('min_amount')->default(100);
            $table->unsignedInteger('target_amount')->nullable();
            $table->unsignedTinyInteger('fee_percent')->default(0);
            $table->boolean('recurring')->default(false);
            $table->string('visibility', 20)->default('publique');
            $table->boolean('active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::table('cagnottes', function (Blueprint $table) {
            $table->boolean('recurring')->default(false)->after('visibility');
            // Première édition de la série. Nul sur l'édition d'origine, qui porte le lien partagé.
            $table->foreignId('series_id')->nullable()->after('recurring')->constrained('cagnottes')->nullOnDelete();
            $table->unsignedInteger('edition')->default(1)->after('series_id');
            $table->foreignId('template_id')->nullable()->after('edition')->constrained('cagnotte_templates')->nullOnDelete();

            $table->index(['series_id', 'edition']);
        });

        // Une cagnotte créée à partir de maintenant est visible de tous, sauf choix contraire.
        DB::statement("UPDATE cagnottes SET visibility = 'privee' WHERE visibility IS NULL");
    }

    public function down(): void
    {
        Schema::table('cagnottes', function (Blueprint $table) {
            $table->dropConstrainedForeignId('template_id');
            $table->dropConstrainedForeignId('series_id');
            $table->dropColumn(['recurring', 'edition']);
        });

        Schema::dropIfExists('cagnotte_templates');
    }
};
