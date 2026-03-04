<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ApiClient
{
    public function __construct(private readonly AuthStorage $auth) {}

    public function get(string $endpoint, array $query = []): array
    {
        try {
            $response = $this->buildClient()
                ->get($this->url($endpoint), $query);

            return $this->handle($response);
        } catch (ConnectionException $e) {
            Log::warning('[ApiClient] Connection error on GET', [
                'endpoint' => $endpoint,
                'error'    => $e->getMessage(),
            ]);
            return $this->networkError();
        }
    }

    public function post(string $endpoint, array $data = []): array
    {
        try {
            $response = $this->buildClient()
                ->post($this->url($endpoint), $data);

            return $this->handle($response);
        } catch (ConnectionException $e) {
            Log::warning('[ApiClient] Connection error on POST', [
                'endpoint' => $endpoint,
                'error'    => $e->getMessage(),
            ]);
            return $this->networkError();
        }
    }

    public function patch(string $endpoint, array $data = []): array
    {
        try {
            $response = $this->buildClient()
                ->patch($this->url($endpoint), $data);

            return $this->handle($response);
        } catch (ConnectionException $e) {
            Log::warning('[ApiClient] Connection error on PATCH', [
                'endpoint' => $endpoint,
                'error'    => $e->getMessage(),
            ]);
            return $this->networkError();
        }
    }

    public function postMultipart(string $endpoint, array $fields, array $files = []): array
    {
        try {
            $request = $this->buildClient();

            foreach ($fields as $name => $value) {
                if (is_array($value)) {
                    foreach ($value as $item) {
                        $request = $request->attach($name.'[]', json_encode($item), null, ['Content-Type' => 'application/json']);
                    }
                } else {
                    $request = $request->attach($name, (string) $value);
                }
            }

            $response = $request->post($this->url($endpoint));

            return $this->handle($response);
        } catch (ConnectionException $e) {
            Log::warning('[ApiClient] Connection error on POST multipart', [
                'endpoint' => $endpoint,
                'error'    => $e->getMessage(),
            ]);
            return $this->networkError();
        }
    }

    /**
     * Build an HTTP client with shared headers, timeout, and SSL CA bundle.
     * On Windows dev the bundled cacert.pem is used so cURL can verify HTTPS.
     * On Android the php.ini written by LaravelEnvironment already sets curl.cainfo.
     */
    private function buildClient(): PendingRequest
    {
        $client = Http::withHeaders($this->buildHeaders())
            ->connectTimeout(15)
            ->timeout(30);

        // Use the bundled CA certificate when it is present (Windows dev / CI).
        // On Android the system php.ini already points curl.cainfo at cacert.pem.
        $caBundle = base_path('nativephp/android/app/src/main/assets/cacert.pem');
        if (file_exists($caBundle)) {
            $client = $client->withOptions(['verify' => $caBundle]);
        }

        return $client;
    }

    private function buildHeaders(): array
    {
        $headers = ['Accept' => 'application/json'];
        $token = $this->auth->getToken();

        if ($token) {
            $headers['Authorization'] = 'Bearer '.$token;
        }

        return $headers;
    }

    private function handle(Response $response): array
    {
        if ($response->successful()) {
            return $response->json() ?? ['success' => true];
        }

        return match ($response->status()) {
            401 => $this->handleUnauthorized(),
            422 => ['errors' => $response->json('errors', []), 'message' => $response->json('message', 'Validation failed')],
            429 => ['rate_limited' => true, 'message' => 'Too many attempts, please wait.'],
            default => ['server_error' => true, 'message' => $response->json('message') ?? ('Server error ('.$response->status().').')],
        };
    }

    private function handleUnauthorized(): array
    {
        $this->auth->clearAll();

        session()->flash('message', "You've been logged out.");

        return ['unauthorized' => true, 'redirect' => '/login'];
    }

    private function networkError(): array
    {
        return ['network_error' => true, 'message' => 'No connection. Please check your internet.'];
    }

    private function url(string $endpoint): string
    {
        $base = rtrim(config('mobile.api_base_url'), '/');
        $path = ltrim($endpoint, '/');

        return "{$base}/{$path}";
    }
}
