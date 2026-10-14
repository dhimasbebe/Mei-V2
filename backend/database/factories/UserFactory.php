<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'username' => fake()->unique()->numerify('#####'),
            'nama_users' => fake()->name(),
            'role_users' => 'Teknisi',
            'email_users' => fake()->unique()->safeEmail(),
            'password' => Hash::make('password'),
            'remember_token' => Str::random(10),
        ];
    }

    public function admin(): static
    {
        return $this->state(fn () => ['role_users' => 'Admin']);
    }

    public function supervisor(): static
    {
        return $this->state(fn () => ['role_users' => 'Supervisor']);
    }
}
