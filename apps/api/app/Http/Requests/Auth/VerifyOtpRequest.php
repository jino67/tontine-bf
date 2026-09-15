<?php

namespace App\Http\Requests\Auth;

class VerifyOtpRequest extends RequestOtpRequest
{
    public function rules(): array
    {
        return [
            ...parent::rules(),
            'code' => ['required', 'string', 'regex:/^\d{6}$/'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }
}
