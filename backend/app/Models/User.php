<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $primaryKey = 'username';
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'username',
        'nama_users',
        'role_users',
        'email_users',
        'password',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
        ];
    }

    public function isAdmin(): bool
    {
        return strcasecmp($this->role_users, 'Admin') === 0;
    }

    public function isTeknisi(): bool
    {
        return strcasecmp($this->role_users, 'Teknisi') === 0;
    }

    public function isSupervisor(): bool
    {
        return strcasecmp($this->role_users, 'Supervisor') === 0;
    }

    /**
     * Sesi pemeliharaan yang dibuat pengguna ini.
     *
     * Gunakan `User::withCount('maintenance')` di controller agar tidak N+1.
     */
    public function maintenance(): HasMany
    {
        return $this->hasMany(Maintenance::class, 'username', 'username');
    }
}
