<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Payment terms, per invoice. The wording shown on the PDF next to the due
 * date: the invoice's own text wins, else the company default (`invoice_terms`
 * setting), else "Net N" derived from the two dates.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->string('terms', 255)->nullable()->after('due_date');
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('terms');
        });
    }
};
