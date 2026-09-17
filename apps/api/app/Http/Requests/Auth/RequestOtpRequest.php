<?php

namespace App\Http\Requests\Auth;

use App\Support\PhoneNumber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;

class RequestOtpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->input('phone'))) {
            $this->merge(['phone' => PhoneNumber::normalize($this->input('phone')) ?? $this->input('phone')]);
        }

        if (is_string($this->input('email'))) {
            $email = trim($this->input('email'));
            $this->merge(['email' => $email === '' ? null : Str::lower($email)]);
        }
    }

    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:/^\+226\d{8}$/'],
            'email' => ['nullable', 'string', 'email', 'max:190'],
        ];
    }

    public function messages(): array
    {
        return [
            'phone.regex' => 'Numéro de téléphone burkinabè invalide (8 chiffres).',
            'email.email' => 'Adresse e-mail invalide.',
        ];
    }
}
