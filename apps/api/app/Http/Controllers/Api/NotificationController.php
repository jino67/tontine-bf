<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\NotificationResource;
use App\Models\Notification;
use App\Models\NotificationSetting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Messages reçus par un membre, et ce qu'il accepte de recevoir. */
class NotificationController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $notifications = Notification::where('user_id', $request->user()->id)
            ->latest('id')
            ->limit(60)
            ->get();

        return NotificationResource::collection($notifications)->additional([
            'meta' => ['unread' => $notifications->whereNull('read_at')->count()],
        ]);
    }

    public function read(Request $request, Notification $notification): JsonResponse
    {
        abort_unless($notification->user_id === $request->user()->id, 403, 'Ce message ne vous est pas adressé.');

        if ($notification->read_at === null) {
            $notification->update(['read_at' => now()]);
        }

        return response()->json(['data' => NotificationResource::make($notification)]);
    }

    public function readAll(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['message' => 'Tous les messages sont marqués comme lus.']);
    }

    public function settings(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->present(NotificationSetting::forUser($request->user()))]);
    }

    /**
     * Réglages du membre. « muted » liste les objets pour lesquels il ne veut plus de relance,
     * sous la forme « tontine:12 » : couper une tontine ne coupe pas les autres.
     */
    public function updateSettings(Request $request): JsonResponse
    {
        $data = $request->validate([
            'reminders' => ['nullable', 'boolean'],
            'mail' => ['nullable', 'boolean'],
            'push' => ['nullable', 'boolean'],
            'whatsapp' => ['nullable', 'boolean'],
            'sms' => ['nullable', 'boolean'],
            'muted' => ['nullable', 'array', 'max:200'],
            'muted.*' => ['string', 'regex:/^(tontine|cagnotte|organization):\d+$/'],
        ]);

        $settings = NotificationSetting::forUser($request->user());
        $settings->update($data);

        return response()->json(['data' => $this->present($settings)]);
    }

    /** @return array<string, mixed> */
    private function present(NotificationSetting $settings): array
    {
        return [
            'reminders' => $settings->reminders,
            'mail' => $settings->mail,
            'push' => $settings->push,
            'whatsapp' => $settings->whatsapp,
            'sms' => $settings->sms,
            'muted' => $settings->muted ?? [],
        ];
    }
}
