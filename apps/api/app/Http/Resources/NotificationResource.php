<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class NotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'label' => $this->type->label(),
            'title' => $this->title,
            'body' => $this->body,
            'channel' => $this->channel->value,
            'status' => $this->status,
            // De quoi ouvrir directement la bonne fiche dans l'application.
            'related' => $this->related_type === null ? null : [
                'kind' => strtolower(class_basename($this->related_type)),
                'id' => $this->related_id,
            ],
            'organization_id' => $this->organization_id,
            'read' => $this->read_at !== null,
            'sent_at' => $this->sent_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
