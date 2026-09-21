<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Visibilité et partage. Tout ce qui existe reste privé : les valeurs par défaut
     * reproduisent exactement le comportement actuel.
     */
    public function up(): void
    {
        Schema::table('organizations', function (Blueprint $table) {
            $table->string('visibility', 20)->default('privee');
            $table->string('join_policy', 20)->default('fermee');
            $table->string('share_code', 12)->nullable();
            $table->unique('share_code');
        });

        Schema::table('tontines', function (Blueprint $table) {
            $table->string('visibility', 20)->default('privee');
            $table->string('join_policy', 20)->default('fermee');
            $table->string('share_code', 12)->nullable();
            $table->unique('share_code');
        });

        Schema::table('cagnottes', function (Blueprint $table) {
            $table->string('visibility', 20)->default('privee');
            $table->string('share_code', 12)->nullable();
            $table->unique('share_code');
        });
    }

    public function down(): void
    {
        Schema::table('organizations', function (Blueprint $table) {
            $table->dropUnique(['share_code']);
            $table->dropColumn(['visibility', 'join_policy', 'share_code']);
        });

        Schema::table('tontines', function (Blueprint $table) {
            $table->dropUnique(['share_code']);
            $table->dropColumn(['visibility', 'join_policy', 'share_code']);
        });

        Schema::table('cagnottes', function (Blueprint $table) {
            $table->dropUnique(['share_code']);
            $table->dropColumn(['visibility', 'share_code']);
        });
    }
};
