<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Espace personnel.
     *
     * Personne n'est obligé d'appartenir à un groupement pour se servir de l'application :
     * un compte sans organisation reçoit le sien, invisible des autres, qui porte ses tontines,
     * ses cagnottes et son portefeuille. Cela évite de dupliquer tout le cloisonnement déjà en place.
     */
    public function up(): void
    {
        Schema::table('organizations', function (Blueprint $table) {
            $table->string('kind', 20)->default('standard')->after('slug');
        });
    }

    public function down(): void
    {
        Schema::table('organizations', function (Blueprint $table) {
            $table->dropColumn('kind');
        });
    }
};
