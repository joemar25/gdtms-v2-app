<?php

namespace Tests\Feature\Auth;

use App\Services\ApiClient;
use App\Services\AuthStorage;
use App\Services\DeviceInfo;
use Mockery;
use Tests\TestCase;

class LoginTest extends TestCase
{
    private array $deviceInfoArray = [
        'os'           => 'android',
        'app_version'  => '1.0.0',
        'device_model' => 'Test Device',
        'device_id'    => 'test-device-id',
    ];

    private function mockDevice(): void
    {
        $this->mock(DeviceInfo::class, function ($mock) {
            $mock->shouldReceive('toArray')
                 ->andReturn($this->deviceInfoArray);
        });
    }

    /** @test */
    public function successful_login_redirects_to_dashboard(): void
    {
        $apiResponse = [
            'data' => [
                'token'   => 'test-token-123',
                'user'    => [
                    'id'           => 1,
                    'first_name'   => 'Juan',
                    'last_name'    => 'Dela Cruz',
                    'phone_number' => 'REDACTED_TEST_NUMBER',
                    'email'        => null,
                ],
                'courier' => [
                    'id'           => 1,
                    'courier_code' => 'CC99999',
                    'courier_type' => 'standard',
                    'branch_id'    => 1,
                ],
            ],
        ];

        $expectedCourier = array_merge(
            $apiResponse['data']['user'],
            $apiResponse['data']['courier']
        );

        $this->mock(ApiClient::class, function ($mock) use ($apiResponse) {
            $mock->shouldReceive('post')
                 ->once()
                 ->with('login', Mockery::type('array'))
                 ->andReturn($apiResponse);
        });

        $this->mock(AuthStorage::class, function ($mock) use ($expectedCourier) {
            $mock->shouldReceive('getToken')->andReturn('test-token-123');
            $mock->shouldReceive('isAuthenticated')->andReturnTrue();
            $mock->shouldReceive('setToken')
                 ->once()
                 ->with('test-token-123');
            $mock->shouldReceive('setCourier')
                 ->once()
                 ->with($expectedCourier);
            $mock->shouldReceive('getCourier')->andReturn($expectedCourier);
        });

        $this->mockDevice();

        $response = $this->post('/login', [
            'phone_number' => 'REDACTED_TEST_NUMBER',
            'password'     => 'REDACTED_TEST_NUMBER',
        ]);

        $response->assertRedirect('/dashboard');
    }

    /** @test */
    public function wrong_credentials_returns_inline_error(): void
    {
        $this->mock(ApiClient::class, function ($mock) {
            $mock->shouldReceive('post')
                 ->once()
                 ->with('login', Mockery::type('array'))
                 ->andReturn(['unauthorized' => true, 'redirect' => '/login']);
        });

        $this->mock(AuthStorage::class, function ($mock) {
            $mock->shouldReceive('getToken')->andReturnNull();
            $mock->shouldReceive('isAuthenticated')->andReturnFalse();
        });

        $this->mockDevice();

        $response = $this->post('/login', [
            'phone_number' => 'REDACTED_TEST_NUMBER',
            'password'     => 'wrongpassword',
        ]);

        $response->assertRedirect();
        $response->assertSessionHasErrors(['phone_number' => 'Invalid phone number or password.']);
        $this->assertFalse($response->getSession()->has('message'));
    }

    /** @test */
    public function rate_limited_response_returns_error_message(): void
    {
        $this->mock(ApiClient::class, function ($mock) {
            $mock->shouldReceive('post')
                 ->once()
                 ->with('login', Mockery::type('array'))
                 ->andReturn([
                     'rate_limited' => true,
                     'message'      => 'Too many attempts, please wait.',
                 ]);
        });

        $this->mock(AuthStorage::class, function ($mock) {
            $mock->shouldReceive('getToken')->andReturnNull();
            $mock->shouldReceive('isAuthenticated')->andReturnFalse();
        });

        $this->mockDevice();

        $response = $this->post('/login', [
            'phone_number' => 'REDACTED_TEST_NUMBER',
            'password'     => 'REDACTED_TEST_NUMBER',
        ]);

        $response->assertSessionHasErrors(['phone_number' => 'Too many attempts, please wait.']);
    }

    /** @test */
    public function validation_error_returns_field_level_errors(): void
    {
        $this->mock(ApiClient::class, function ($mock) {
            $mock->shouldReceive('post')
                 ->once()
                 ->with('login', Mockery::type('array'))
                 ->andReturn([
                     'errors' => [
                         'phone_number' => ['The phone number field is required.'],
                     ],
                 ]);
        });

        $this->mock(AuthStorage::class, function ($mock) {
            $mock->shouldReceive('getToken')->andReturnNull();
            $mock->shouldReceive('isAuthenticated')->andReturnFalse();
        });

        $this->mockDevice();

        $response = $this->post('/login', [
            'phone_number' => 'REDACTED_TEST_NUMBER',
            'password'     => 'REDACTED_TEST_NUMBER',
        ]);

        $response->assertSessionHasErrors(['phone_number']);
    }

    /** @test */
    public function network_error_returns_connection_error_message(): void
    {
        $this->mock(ApiClient::class, function ($mock) {
            $mock->shouldReceive('post')
                 ->once()
                 ->with('login', Mockery::type('array'))
                 ->andReturn([
                     'network_error' => true,
                     'message'       => 'No connection. Please check your internet.',
                 ]);
        });

        $this->mock(AuthStorage::class, function ($mock) {
            $mock->shouldReceive('getToken')->andReturnNull();
            $mock->shouldReceive('isAuthenticated')->andReturnFalse();
        });

        $this->mockDevice();

        $response = $this->post('/login', [
            'phone_number' => 'REDACTED_TEST_NUMBER',
            'password'     => 'REDACTED_TEST_NUMBER',
        ]);

        $response->assertSessionHasErrors(['phone_number' => 'No connection. Please check your internet.']);
    }
}
