<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CagnotteTemplate;
use Illuminate\Http\JsonResponse;

/** Formules de cagnotte préparées depuis le back-office, proposées à la création. */
class CagnotteTemplateController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $templates = CagnotteTemplate::query()->usable()->get()->map(fn (CagnotteTemplate $template) => [
            'id' => $template->id,
            'name' => $template->name,
            'description' => $template->description,
            'mode' => $template->mode->value,
            'duration' => $template->duration->value,
            'ticket_price' => $template->ticket_price,
            'winners_count' => $template->winners_count,
            'prize_split' => $template->prize_split,
            'min_amount' => $template->min_amount,
            'target_amount' => $template->target_amount,
            'fee_percent' => $template->fee_percent,
            'recurring' => $template->recurring,
            'visibility' => $template->visibility->value,
        ]);

        return response()->json(['data' => $templates]);
    }
}
