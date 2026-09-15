<?php

namespace App\Services\PayDunya;

use App\Exceptions\DomainRuleException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * API HTTP/JSON de PayDunya : factures de paiement (sandbox ou production) et déboursements (v2, production seulement).
 * Documentation : https://developers.paydunya.com/doc/FR/http_json et /doc/FR/api_deboursement
 */
class PayDunyaClient
{
    private array $config;

    public function __construct()
    {
        $this->config = config('services.paydunya');
    }

    public function isLive(): bool
    {
        return $this->config['mode'] === 'live';
    }

    /** PayDunya signe ses notifications avec le SHA-512 de la clé principale. */
    public function isAuthentic(mixed $hash): bool
    {
        return is_string($hash)
            && filled($this->config['master_key'])
            && hash_equals(hash('sha512', $this->config['master_key']), $hash);
    }

    /** @return array{token: string, url: string} */
    public function createInvoice(int $amount, string $description, array $customData, array $actions): array
    {
        $body = $this->post($this->checkoutPath('create'), [
            'invoice' => ['total_amount' => $amount, 'description' => $description],
            'store' => ['name' => $this->config['store_name']],
            'custom_data' => $customData,
            'actions' => $actions,
        ]);

        if (($body['response_code'] ?? null) !== '00' || empty($body['token'])) {
            $this->fail('création de facture refusée', $body);
        }

        return ['token' => $body['token'], 'url' => $body['response_text']];
    }

    /** Statut d'une facture : pending, completed, cancelled ou failed. */
    public function confirmInvoice(string $token): array
    {
        try {
            $body = $this->http()->get($this->checkoutPath('confirm/'.rawurlencode($token)))->json() ?? [];
        } catch (ConnectionException) {
            $this->fail('service injoignable', []);
        }

        if (! isset($body['status'])) {
            $this->fail('statut de facture illisible', $body);
        }

        return $body;
    }

    /**
     * Crée puis soumet un déboursement. Le statut peut être success, pending ou failed.
     *
     * @return array{token: string, body: array}
     */
    public function disburse(string $phone, int $amount, string $withdrawMode, string $callbackUrl, string $disburseId): array
    {
        $invoice = $this->post('/api/v2/disburse/get-invoice', [
            'account_alias' => $phone,
            'amount' => $amount,
            'withdraw_mode' => $withdrawMode,
            'callback_url' => $callbackUrl,
        ]);

        if (($invoice['response_code'] ?? null) !== '00' || empty($invoice['disburse_token'])) {
            $this->fail('remise refusée', $invoice, 'PayDunya a refusé la remise : '.($invoice['response_text'] ?? 'vérifiez le numéro et l’opérateur.'));
        }

        $submitted = $this->post('/api/v2/disburse/submit-invoice', [
            'disburse_invoice' => $invoice['disburse_token'],
            'disburse_id' => $disburseId,
        ]);

        return ['token' => $invoice['disburse_token'], 'body' => $submitted];
    }

    public function disburseStatus(string $token): array
    {
        return $this->post('/api/v2/disburse/check-status', ['disburse_invoice' => $token]);
    }

    private function checkoutPath(string $action): string
    {
        return ($this->isLive() ? '/api/v1/checkout-invoice/' : '/sandbox-api/v1/checkout-invoice/').$action;
    }

    private function post(string $path, array $payload): array
    {
        try {
            return $this->http()->post($path, $payload)->json() ?? [];
        } catch (ConnectionException) {
            $this->fail('service injoignable', []);
        }
    }

    private function http(): PendingRequest
    {
        if (blank($this->config['master_key']) || blank($this->config['private_key']) || blank($this->config['token'])) {
            throw new DomainRuleException('Le paiement en ligne n’est pas encore configuré sur ce serveur.');
        }

        return Http::baseUrl('https://app.paydunya.com')
            ->acceptJson()
            ->asJson()
            ->timeout(30)
            ->withHeaders([
                'PAYDUNYA-MASTER-KEY' => $this->config['master_key'],
                'PAYDUNYA-PRIVATE-KEY' => $this->config['private_key'],
                'PAYDUNYA-TOKEN' => $this->config['token'],
            ]);
    }

    private function fail(string $reason, array $body, ?string $message = null): never
    {
        Log::warning("PayDunya : {$reason}", ['response' => $body]);

        throw new DomainRuleException($message ?? 'Le service de paiement ne répond pas correctement. Réessayez dans quelques instants.');
    }
}
